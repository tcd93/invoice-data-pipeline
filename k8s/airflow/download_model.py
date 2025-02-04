from transformers import DonutProcessor, VisionEncoderDecoderModel
import os

def download_model(model_path):
    """Download a Hugging Face model to the specified directory"""
    if not os.path.exists(model_path):
        os.makedirs(model_path)

    model_ckpt = "naver-clova-ix/donut-base-finetuned-cord-v2"
    model = VisionEncoderDecoderModel.from_pretrained(model_ckpt)
    processor = DonutProcessor.from_pretrained(model_ckpt)

    model.save_pretrained(model_path)
    processor.save_pretrained(model_path)

download_model('/home/airflow/.cache')