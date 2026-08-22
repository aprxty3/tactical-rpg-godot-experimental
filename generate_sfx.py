import wave
import math
import struct
import os

def generate_tone(filename, duration_ms, frequency, decay=True, noise=False):
    os.makedirs("assets/sfx", exist_ok=True)
    filepath = f"assets/audio/sfx/{filename}"
    
    sample_rate = 44100
    num_samples = int((duration_ms / 1000.0) * sample_rate)
    
    wav_file = wave.open(filepath, 'w')
    wav_file.setnchannels(1) # Mono
    wav_file.setsampwidth(2) # 2 bytes per sample (16-bit)
    wav_file.setframerate(sample_rate)
    
    import random
    
    for i in range(num_samples):
        t = float(i) / sample_rate
        # Envelope: linear decay
        envelope = 1.0 - (i / num_samples) if decay else 1.0
        
        if noise:
            value = random.uniform(-1.0, 1.0) * envelope
        else:
            value = math.sin(2.0 * math.pi * frequency * t) * envelope
            
        # Scale to 16-bit integer range
        packed_value = struct.pack('h', int(value * 32767.0 * 0.5))
        wav_file.writeframes(packed_value)
        
    wav_file.close()
    print(f"Generated {filepath}")

# Generate a quick high pitch beep for move
generate_tone("move.wav", duration_ms=100, frequency=440.0)

# Generate a low frequency / noisy thud for attack impact
generate_tone("hit.wav", duration_ms=250, frequency=150.0, noise=True)

# Generate a pleasant chime for victory
generate_tone("victory.wav", duration_ms=1000, frequency=880.0)

# Generate a low tone for defeat
generate_tone("defeat.wav", duration_ms=1000, frequency=220.0)

