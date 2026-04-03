import argparse

import numpy as np
import soundfile as sf


def _one_pole_lowpass(x: np.ndarray, cutoff_hz: float, sr: int) -> np.ndarray:
	if cutoff_hz <= 0:
		return np.zeros_like(x)
	rc = 1.0 / (2.0 * np.pi * cutoff_hz)
	dt = 1.0 / sr
	alpha = dt / (rc + dt)
	y = np.empty_like(x)
	y[0] = alpha * x[0]
	for i in range(1, len(x)):
		y[i] = y[i - 1] + alpha * (x[i] - y[i - 1])
	return y


def _random_voice_like(sr: int, duration_s: float, seed: int | None = None) -> np.ndarray:
	rng = np.random.default_rng(seed)
	n = int(sr * duration_s)
	t = np.arange(n, dtype=np.float32) / sr

	# Random smooth pitch contour across the clip
	anchors = rng.uniform(95.0, 240.0, size=max(4, int(duration_s) + 2)).astype(np.float32)
	anchor_times = np.linspace(0, duration_s, len(anchors), dtype=np.float32)
	f0 = np.interp(t, anchor_times, anchors)

	# Random voiced/unvoiced gate to mimic syllables
	seg_len = int(sr * 0.08)
	gate = np.zeros(n, dtype=np.float32)
	for start in range(0, n, seg_len):
		end = min(n, start + seg_len)
		gate[start:end] = 1.0 if rng.random() > 0.25 else 0.0
	# Smooth gate transitions
	win = np.hanning(max(16, int(sr * 0.01)))
	win = win / np.sum(win)
	gate = np.convolve(gate, win, mode="same").astype(np.float32)

	# Harmonic source with random phases and amplitudes
	phase = 2.0 * np.pi * np.cumsum(f0) / sr
	source = np.zeros(n, dtype=np.float32)
	harmonics = 8
	for h in range(1, harmonics + 1):
		amp = (1.0 / h) * rng.uniform(0.7, 1.2)
		source += amp * np.sin(h * phase + rng.uniform(0, 2 * np.pi)).astype(np.float32)

	# Breath/noise component
	noise = rng.normal(0.0, 1.0, n).astype(np.float32)
	noise = _one_pole_lowpass(noise, cutoff_hz=3500.0, sr=sr)
	voiced = gate * source + (1.0 - gate) * 0.22 * noise

	# Very simple formant-like filtering via cascaded low-pass bands
	f1 = rng.uniform(450.0, 850.0)
	f2 = rng.uniform(1100.0, 2200.0)
	f3 = rng.uniform(2200.0, 3300.0)
	band1 = _one_pole_lowpass(voiced, cutoff_hz=f1, sr=sr)
	band2 = _one_pole_lowpass(voiced, cutoff_hz=f2, sr=sr) - band1
	band3 = _one_pole_lowpass(voiced, cutoff_hz=f3, sr=sr) - _one_pole_lowpass(voiced, cutoff_hz=f2, sr=sr)
	y = 0.65 * band1 + 0.45 * band2 + 0.20 * band3

	# Amplitude envelope
	env_anchors = rng.uniform(0.35, 1.0, size=max(5, int(duration_s) + 3)).astype(np.float32)
	env_times = np.linspace(0, duration_s, len(env_anchors), dtype=np.float32)
	env = np.interp(t, env_times, env_anchors).astype(np.float32)
	y = y * env

	# Normalize with headroom
	peak = float(np.max(np.abs(y)) + 1e-9)
	y = (0.9 * y / peak).astype(np.float32)
	return y


def main() -> None:
	parser = argparse.ArgumentParser(description="Generate a randomized voice-like test WAV")
	parser.add_argument("--out", default="test.wav", help="Output wav path")
	parser.add_argument("--sr", type=int, default=44100, help="Sample rate")
	parser.add_argument("--duration", type=float, default=5.0, help="Duration in seconds")
	parser.add_argument("--seed", type=int, default=None, help="Random seed for reproducible output")
	args = parser.parse_args()

	wav = _random_voice_like(sr=args.sr, duration_s=args.duration, seed=args.seed)
	sf.write(args.out, wav, args.sr, subtype="PCM_16")
	print(f"Wrote {args.out} (voice-like random audio)")


if __name__ == "__main__":
	main()
