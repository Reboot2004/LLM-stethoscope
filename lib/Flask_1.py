from flask import Flask, request, jsonify
import numpy as np
import librosa
from PIL import Image
import io
import torch
from keras.models import load_model
from torchvision import transforms
import cv2
import matplotlib.pyplot as plt
import traceback
app = Flask(__name__)

# Load the trained models
mel_dl_model_path = 'llm_stethoscope_model.h5'
try:
    model2 = load_model(mel_dl_model_path)
except Exception as e:
    print(f"Error loading Keras model 2: {str(e)}")
    model2 = None

vit_model_path = r'vit_model (2).pth'
try:
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    vit_model = torch.load(vit_model_path, map_location=device)
    vit_model.eval()
except Exception as e:
    print(f"Error loading PyTorch VIT model: {str(e)}")
    vit_model = None

vit_model_path2 = r"vit_model_350_pre.pth"
try:
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    vit_model2 = torch.load(vit_model_path2, map_location=device)
    vit_model2.eval()
except Exception as e:
    print(f"Error loading PyTorch VIT model 2: {str(e)}")
    vit_model2 = None

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

def normalize_spectrogram(spectrogram, target_shape=(20, 157)):
    if spectrogram.shape[1] > target_shape[1]:
        spectrogram = spectrogram[:, :target_shape[1]]  # Trim
    elif spectrogram.shape[1] < target_shape[1]:
        spectrogram = np.pad(spectrogram, ((0, 0), (0, target_shape[1] - spectrogram.shape[1])), 'constant')  # Pad
    if spectrogram.shape[0] > target_shape[0]:
        spectrogram = spectrogram[:target_shape[0], :]  # Trim
    elif spectrogram.shape[0] < target_shape[0]:
        spectrogram = np.pad(spectrogram, ((0, target_shape[0] - spectrogram.shape[0]), (0, 0)), 'constant')  # Pad

    return spectrogram

def audio_to_mel_spectrogram(audio_data, sr):
    S = librosa.feature.melspectrogram(y=audio_data, sr=sr, n_fft=2048, hop_length=512, n_mels=128)
    S_dB = librosa.power_to_db(S, ref=np.max)
    S_dB_resized = normalize_spectrogram(S_dB)

    # Resize to match (20, 157)
    S_dB_resized = cv2.resize(S_dB_resized, (157, 20), interpolation=cv2.INTER_AREA)
    S_dB_resized = S_dB_resized[np.newaxis, ..., np.newaxis]  # Add channel and batch dimension

    return S_dB_resized

def audio_to_fft_spectrogram(audio_data, sr):
    D = np.abs(librosa.stft(audio_data))**2
    S = librosa.amplitude_to_db(D, ref=np.max)

    # Resize or crop S to match (20, 157)
    S_resized = cv2.resize(S, (157, 20), interpolation=cv2.INTER_AREA)

    plt.figure(figsize=(10, 4))
    librosa.display.specshow(S_resized, sr=sr, x_axis='time', y_axis='log')
    plt.colorbar(format='%+2.0f dB')
    plt.tight_layout()
    spectrogram_image_path_with_axis = 'fft_spectrogram_with_axis.png'
    plt.savefig(spectrogram_image_path_with_axis, bbox_inches='tight', pad_inches=0)
    plt.close()

    return spectrogram_image_path_with_axis

@app.route('/FFT_Spectrogram', methods=['POST'])
def upload_fft_spectrogram():
    if 'audio' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    audio_file = request.files['audio']
    audio_data, sr = librosa.load(audio_file, sr=None)

    # Apply noise reduction
    audio_data = apply_noise_reduction(audio_data, sr)

    # Create FFT spectrogram
    S = np.abs(librosa.stft(audio_data, n_fft=2048, hop_length=512))
    S_dB = librosa.amplitude_to_db(S, ref=np.max)
    S_dB = normalize_spectrogram(S_dB)

    S_dB = S_dB[np.newaxis, ..., np.newaxis]

    predictions = model2.predict(S_dB)
    predicted_class_index = np.argmax(predictions, axis=1)

    class_names = ['Asthma', 'Bronchiectasis', 'Bronchiolitis', 'COPD', 'Healthy', 'LRTI', 'Pneumonia', 'URTI']
    predicted_label = class_names[predicted_class_index[0]]

    return jsonify({'predicted_class': predicted_label})

@app.route('/Mel_Spectrogram', methods=['POST'])
def upload_mel_spectrogram():
    if 'audio' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    audio_file = request.files['audio']
    audio_data, sr = librosa.load(audio_file, sr=None)

    S_dB_resized = audio_to_mel_spectrogram(audio_data, sr)

    predictions = model2.predict(S_dB_resized)
    predicted_class_index = np.argmax(predictions, axis=1)

    class_names = ['Asthma', 'Bronchiectasis', 'Bronchiolitis', 'COPD', 'Healthy', 'LRTI', 'Pneumonia', 'URTI']
    predicted_label = class_names[predicted_class_index[0]]

    return jsonify({'predicted_class': predicted_label})



@app.route('/LLM_Mel', methods=['POST'])
def llm_mel_model():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    try:
        file_stream = io.BytesIO(file.read())
        audio_data, sr = librosa.load(file_stream, sr=None)

        # Apply noise reduction
        audio_data = apply_noise_reduction(audio_data, sr)

        # Convert to Mel spectrogram
        S_dB_resized = audio_to_mel_spectrogram(audio_data, sr)

        # Resize the spectrogram to match VIT model input size (224, 224)
        S_dB_resized = cv2.resize(S_dB_resized.squeeze(), (224, 224))

        # Expand the single channel to 3 channels
        S_dB_resized = np.stack((S_dB_resized,) * 3, axis=-1)

        # Convert to tensor and add batch dimension
        image = transforms.ToTensor()(S_dB_resized).unsqueeze(0)

        with torch.no_grad():
            outputs = vit_model(image)
            _, predicted = torch.max(outputs, 1)

        class_names = ['Asthma', 'Bronchiectasis', 'Bronchiolitis', 'COPD', 'Healthy', 'LRTI', 'Pneumonia', 'URTI']
        predicted_class = class_names[predicted.item()]

        return jsonify({'predicted_class': predicted_class}), 200
    except Exception as e:
        error_trace = traceback.format_exc()
        print(f"Error in /LLM_Mel: {str(e)}")
        print(error_trace)
        return jsonify({'error': str(e), 'trace': error_trace}), 500

@app.route('/LLM_FFT', methods=['POST'])
def llm_fft_model():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    try:
        file_stream = io.BytesIO(file.read())
        audio_data, sr = librosa.load(file_stream, sr=None)

        # Apply noise reduction
        audio_data = apply_noise_reduction(audio_data, sr)

        # Use the audio_to_fft_spectrogram function to create the spectrogram
        spectrogram_path = audio_to_fft_spectrogram(audio_data, sr)
        image = Image.open(spectrogram_path).convert('RGB')
        image = transform(image)
        image = image.unsqueeze(0)  # Add batch dimension

        with torch.no_grad():
            outputs = vit_model2(image)
            _, predicted = torch.max(outputs, 1)

        class_names = ['Asthma', 'Bronchiectasis', 'Bronchiolitis', 'COPD', 'Healthy', 'LRTI', 'Pneumonia', 'URTI']
        predicted_class = class_names[predicted.item()]

        return jsonify({'predicted_class': predicted_class}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port = 1000, host = '0.0.0.0')
