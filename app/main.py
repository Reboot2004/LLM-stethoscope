from flask import Flask, request, jsonify
import numpy as np
import librosa
from PIL import Image
import io
import os
import torch
import torchaudio
from keras.models import load_model
import matplotlib.pyplot as plt
from torchvision import transforms
from torch import nn
import torch.nn.functional as F
import cv2
app = Flask(__name__)

# Load the trained models
model_path = 'lung_disease_model_with_flatten.h5'
model = load_model(model_path)

mel_dl_model_path = 'llm_stethoscope_model.h5'
model2 = load_model(mel_dl_model_path)

vit_model_path = r'vit_model (2).pth'
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
vit_model = torch.load(vit_model_path, map_location=device)
vit_model.eval()

vit_model_path2 = r"vit_model_350_pre.pth"
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
vit_model2 = torch.load(vit_model_path2, map_location=device)
vit_model2.eval()

# Define transformations
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.5], [0.5])
])

def hanning(N):
    alpha = 0.54
    beta = 1 - alpha
    n = np.arange(N)
    return alpha - beta * np.cos(2 * np.pi * n / (N - 1))

def audio_to_fft_spectrogram(audio_data, sr):
    D = np.abs(librosa.stft(audio_data))**2
    S = librosa.amplitude_to_db(D, ref=np.max)

    plt.figure(figsize=(10, 4))
    librosa.display.specshow(S, sr=sr, x_axis='time', y_axis='log')
    plt.colorbar(format='%+2.0f dB')
    plt.tight_layout()
    spectrogram_image_path_with_axis = 'fft_spectrogram_with_axis.png'
    plt.savefig(spectrogram_image_path_with_axis, bbox_inches='tight', pad_inches=0)
    plt.close()

    return spectrogram_image_path_with_axis

def apply_noise_reduction(audio_data, sr):
    D = librosa.stft(audio_data, n_fft=2048, window=hanning(2048))
    magnitude = np.abs(D)
    phase = np.angle(D)
    noise_mean = np.mean(magnitude[:, :5], axis=1, keepdims=True)
    mask = magnitude > noise_mean
    magnitude_filtered = magnitude * mask
    D_filtered = magnitude_filtered * np.exp(1j * phase)
    y_filtered = librosa.istft(D_filtered)
    return y_filtered

def normalize_spectrogram(spectrogram, target_shape=(128, 128)):
    if spectrogram.shape[1] > target_shape[1]:
        spectrogram = spectrogram[:, :target_shape[1]]  # Trim
    elif spectrogram.shape[1] < target_shape[1]:
        spectrogram = np.pad(spectrogram, ((0, 0), (0, target_shape[1] - spectrogram.shape[1])), 'constant')  # Pad
    if spectrogram.shape[0] > target_shape[0]:
        spectrogram = spectrogram[:target_shape[0], :]  # Trim
    elif spectrogram.shape[0] < target_shape[0]:
        spectrogram = np.pad(spectrogram, ((0, target_shape[0] - spectrogram.shape[0]), (0, 0)), 'constant')  # Pad

    return spectrogram


def apply_noise_reduction_mel(audio_data, sr):
    D = librosa.stft(audio_data, n_fft=2048, hop_length=512)
    magnitude = np.abs(D)
    noise_mean = np.mean(magnitude[:, :5], axis=1, keepdims=True)
    mask = magnitude > noise_mean
    magnitude_filtered = magnitude * mask
    D_filtered = magnitude_filtered * np.exp(1j * np.angle(D))
    y_filtered = librosa.istft(D_filtered)
    return y_filtered
def resize_or_crop_to_match(spectrogram, target_shape=(20, 157)):
    # Implement your logic to resize or crop spectrogram to match target_shape
    # Example resizing:
    spectrogram_resized = cv2.resize(spectrogram, target_shape[::-1], interpolation=cv2.INTER_AREA)
    return spectrogram_resized
# Function to normalize spectrogram
def normalize_spectrogram_mel(spectrogram, target_shape=(224, 224)):
    if spectrogram.shape[1] > target_shape[1]:
        spectrogram = spectrogram[:, :target_shape[1]]
    elif spectrogram.shape[1] < target_shape[1]:
        spectrogram = np.pad(spectrogram, ((0, 0), (0, target_shape[1] - spectrogram.shape[1])), 'constant')
    return spectrogram

def audio_to_mel_spectrogram(audio_path):
    waveform, sr = torchaudio.load(audio_path)
    mel_spectrogram = torchaudio.transforms.MelSpectrogram()(waveform)
    mel_spectrogram_db = torchaudio.transforms.AmplitudeToDB()(mel_spectrogram)

    mel_spectrogram_np = mel_spectrogram_db.squeeze().cpu().numpy()
    plt.figure(figsize=(10, 4))
    plt.imshow(mel_spectrogram_np, cmap='inferno')
    plt.axis('off')
    plt.savefig('mel_spectrogram.png', bbox_inches='tight', pad_inches=0)
    plt.close()
    image = Image.open('mel_spectrogram.png').convert('RGB')
    return image

@app.route('/FFT_Spectrogram', methods=['POST'])
def upload_file():
    if 'audio' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    audio_file = request.files['audio']
    audio_data, sr = librosa.load(audio_file, sr=None)

    audio_data = apply_noise_reduction(audio_data, sr)
    S = np.abs(librosa.stft(audio_data, n_fft=2048, hop_length=512))
    S_dB = librosa.amplitude_to_db(S, ref=np.max)
    S_dB = normalize_spectrogram(S_dB)

    S_dB = S_dB[np.newaxis, ..., np.newaxis]

    predictions = model.predict(S_dB)
    predicted_class_index = np.argmax(predictions, axis=1)

    class_labels = ['Normal', 'Asthma', 'Heart Failure', 'COPD', 'Lung Fibrosis', 'Pneumonia', 'Bronchial', 'Pleural Effusion', 'Bron', 'Crep']
    predicted_label = class_labels[predicted_class_index[0]]
    print(predicted_label)
    return jsonify({'predicted_class': predicted_label})

@app.route('/Mel_Spectrogram', methods=['POST'])
def mel_spectogram():
    if 'audio' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    audio_file = request.files['audio']
    audio_data, sr = librosa.load(audio_file, sr=None)

    S = librosa.feature.melspectrogram(y=audio_data, sr=sr, n_fft=2048, hop_length=512, n_mels=128)
    S_dB = librosa.power_to_db(S, ref=np.max)
    S_dB = normalize_spectrogram(S_dB)

    S_dB = S_dB[np.newaxis, ..., np.newaxis]
    S_dB_resized = resize_or_crop_to_match(S_dB, target_shape=(20, 157))

    S_dB_resized = S_dB_resized[np.newaxis, ..., np.newaxis]

    predictions = model2.predict(S_dB_resized)
    predicted_class_index = np.argmax(predictions, axis=1)

    class_labels = ['Normal', 'Asthma', 'Heart Failure', 'COPD', 'Lung Fibrosis', 'Pneumonia', 'Bronchial', 'Pleural Effusion', 'Bron', 'Crep']
    predicted_label = class_labels[predicted_class_index[0]]

    return jsonify({'predicted_class': predicted_label})

@app.route('/LLM_Mel', methods=['POST'])
def llm_model():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    if file:
        try:
            file_stream = io.BytesIO(file.read())
            audio_data, sr = librosa.load(file_stream, sr=None)
            audio_data = apply_noise_reduction(audio_data, sr)
            S = librosa.feature.melspectrogram(y=audio_data, sr=sr, n_fft=2048, hop_length=512)
            S_dB = librosa.power_to_db(S, ref=np.max)
            S_dB = normalize_spectrogram(S_dB)

            S_dB_rgb = np.stack([S_dB, S_dB, S_dB], axis=-1)  # Create RGB-like image

            image = Image.fromarray((S_dB_rgb * 255).astype('uint8'), 'RGB')
            image = transform(image)
            image = image.unsqueeze(0)  # Add batch dimension

            with torch.no_grad():
                outputs = vit_model(image)
                _, predicted = torch.max(outputs, 1)

            class_names = ['Normal', 'Asthma', 'Heart Failure', 'COPD', 'Lung Fibrosis', 'Pneumonia', 'Bronchial', 'Pleural Effusion', 'Bron', 'Crep'] #os.listdir(r'C:\Users\alaka\OneDrive\Desktop\Surya\PROJECT SCHOOL\Flutter (PS)\llm_stethoscope\Audio Files VIT TT (2)\Audio Files VIT TT\TRAIN')
            predicted_class = class_names[predicted.item()]

            return jsonify({'predicted_class': predicted_class}), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 500

@app.route('/LLM_FFT', methods=['POST'])
def llm_model2():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    if file:
        try:
            file_stream = io.BytesIO(file.read())
            audio_data, sr = librosa.load(file_stream, sr=None)
            audio_data = apply_noise_reduction(audio_data, sr)

            # Use the audio_to_fft_spectrogram function to create the spectrogram
            spectrogram_path = audio_to_fft_spectrogram(audio_data, sr)
            image = Image.open(spectrogram_path).convert('RGB')
            image = transform(image)
            image = image.unsqueeze(0)  # Add batch dimension

            with torch.no_grad():
                outputs = vit_model2(image)
                _, predicted = torch.max(outputs, 1)

            class_names = ['Normal', 'Asthma', 'Heart Failure', 'COPD', 'Lung Fibrosis', 'Pneumonia', 'Bronchial', 'Pleural Effusion', 'Bron', 'Crep']#os.listdir(r'C:\Users\alaka\OneDrive\Desktop\Surya\PROJECT SCHOOL\Flutter (PS)\llm_stethoscope\Audio Files VIT TT (2)\Audio Files VIT TT\TRAIN')
            predicted_class = class_names[predicted.item()]

            return jsonify({'predicted_class': predicted_class}), 200
        except Exception as e:
            return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=1000)