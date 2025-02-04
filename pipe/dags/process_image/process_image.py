from airflow.decorators import dag, task

@dag(
    start_date=None,
    schedule_interval=None,
)
def process_image():
    @task
    def get_images_from_s3() -> list[str]:
        from airflow.providers.amazon.aws.operators.s3 import S3Hook
        # aws_default is created by set up script
        hook = S3Hook(aws_conn_id='aws_default')
        objects = hook.list_keys(bucket_name='lake', prefix='invoices')
        return [
            hook.download_file(
                key=obj, 
                bucket_name='lake', # lake bucket should be pre-created by set up script
                local_path='/tmp/', 
                preserve_file_name=True
            ) for obj in objects
        ]

    @task
    def image_to_json(image_path: str) -> dict:
        """
        Process image from pre-trained Donut model into JSON object
        See: https://huggingface.co/docs/transformers/model_doc/donut
        
        This task is slow, enable parallelization by setting AIRFLOW__CORE__MAX_ACTIVE_TASKS_PER_DAG in yaml config if possible
        
        Docker Desktop for Kubernetes does not seem to support GPU acceleration currently (Nvdia CUDA)
        """
        from transformers import DonutProcessor, VisionEncoderDecoderModel
        from transformers.utils import logging
        logging.set_verbosity_error() 

        import torch
        from PIL import Image
        import re

        device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"Using device: {device}")
        print(f"Image: {image_path}")

        # Loading the pretrained model and processor for Information Extraction task
        model_ckpt = "naver-clova-ix/donut-base-finetuned-cord-v2"
        model = VisionEncoderDecoderModel.from_pretrained(model_ckpt).to(device)
        processor = DonutProcessor.from_pretrained(model_ckpt)

        image = Image.open(image_path)

        # Donut processor require RGB image, so convert it before feeding.
        pixel_values = processor(image.convert('RGB'), return_tensors="pt").pixel_values

        # Prepare decoder inputs
        task_prompt = "<s_cord-v2>"
        decoder_input_ids = processor.tokenizer(task_prompt, add_special_tokens=False, return_tensors="pt").input_ids

        outputs = model.generate(
            pixel_values.to(device),
            decoder_input_ids=decoder_input_ids.to(device),
            max_length=model.decoder.config.max_position_embeddings,
            pad_token_id=processor.tokenizer.pad_token_id,
            eos_token_id=processor.tokenizer.eos_token_id,
            use_cache=True,
            bad_words_ids=[[processor.tokenizer.unk_token_id]],
            return_dict_in_generate=True,
        )

        sequence = processor.batch_decode(outputs.sequences)[0]
        sequence = sequence.replace(processor.tokenizer.eos_token, "").replace(processor.tokenizer.pad_token, "")
        sequence = re.sub(r"<.*?>", "", sequence, count=1).strip()  # remove first task start token

        doc = processor.token2json(sequence)
        file_name=image_path.split("/")[-1]
        return {
            'json': doc,
            'file_name': file_name,
        }
    
    @task
    def save_json_to_s3_as_parquet(results: list[dict]) -> str:
        """
        Save the JSON object to S3 as a Parquet file (/warehouse/processed_invoices/)
        """
        import pandas as pd
        from airflow.operators.python import get_current_context

        menu = pd.DataFrame()
        for r in results:
            df = pd.DataFrame(r['json']['menu'] if isinstance(r['json']['menu'], list) else [r['json']['menu']])
            df['file_name'] = r['file_name']
            df['date'] = pd.to_datetime(get_current_context()["ds"])
            menu = pd.concat([menu, df], ignore_index=True)
        menu['unitprice'] = menu['unitprice'].str.replace(r'\D', '', regex=True).astype(float)
        menu['price'] = menu['price'].str.replace(r'\D', '', regex=True).astype(float)
        menu['cnt'] = menu['cnt'].str.replace(r'\D', '', regex=True).astype(int)

        total = pd.DataFrame()
        for r in results:
            total_df = pd.DataFrame(r['json']['total'] if isinstance(r['json']['total'], list) else [r['json']['total']])
            subtotal_df = pd.DataFrame(r['json']['sub_total'] if isinstance(r['json']['sub_total'], list) else [r['json']['sub_total']])
            total = pd.concat([total, pd.concat([total_df, subtotal_df], axis=1)], ignore_index=True)
            total['file_name'] = r['file_name']
            total['date'] = pd.to_datetime(get_current_context()["ds"])

        total['total_price'] = total['total_price'].str.replace(r'\D', '', regex=True).astype(float)
        total['creditcardprice'] = total['creditcardprice'].str.replace(r'\D', '', regex=True).astype(float)
        total['changeprice'] = total['changeprice'].str.replace(r'\D', '', regex=True).astype(float)
        total['cashprice'] = total['cashprice'].str.replace(r'\D', '', regex=True).astype(float)
        total['total_etc'] = total['total_etc'].str.replace(r'\D', '', regex=True).astype(float)
        total['subtotal_price'] = total['subtotal_price'].str.replace(r'\D', '', regex=True).astype(float)
        total['service_price'] = total['service_price'].str.replace(r'\D', '', regex=True).astype(float)
        total['tax_price'] = total['tax_price'].str.replace(r'\D', '', regex=True).astype(float)

        from airflow.providers.amazon.aws.operators.s3 import S3Hook
        hook = S3Hook(aws_conn_id="aws_default")
        import awswrangler as wr
        wr.config.s3_endpoint_url = "http://minio:9000"
        wr.s3.to_parquet(
            df=menu,
            path=f"s3://warehouse/processed_invoices/menu/",
            dataset=True,
            mode="overwrite_partitions",
            partition_cols=["date"],
            boto3_session=hook.get_session(),
        )
        wr.s3.to_parquet(
            df=total,
            path=f"s3://warehouse/processed_invoices/total/",
            dataset=True,
            mode="overwrite_partitions",
            partition_cols=["date"],
            boto3_session=hook.get_session(),
        )

    @task
    def rm_downloaded_images(images: list[str]):
        import os
        for image in images:
            os.remove(image)

    images = get_images_from_s3()
    results = image_to_json.expand(image_path=images)
    save_json_to_s3_as_parquet(results) >> rm_downloaded_images(images)

process_image()