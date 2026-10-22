"""Convert sentence-transformers/all-MiniLM-L6-v2 to a Core ML model for Recall.

Usage (dev machine only; the app itself never downloads anything):
    python -I scripts/convert_minilm.py <model_dir> <out_dir>

<model_dir> is a local copy of the Hugging Face repo (config.json, model.safetensors, vocab.txt).
Writes <out_dir>/MiniLM.mlpackage (fp16) and <out_dir>/minilm-vocab.txt, plus reference.json:
embeddings from sentence-transformers for parity checks against the Swift implementation.
"""
import json
import shutil
import sys

import coremltools as ct
import numpy as np
import torch
from transformers import AutoModel

MAX_TOKENS = 256  # inputs may be any length from 1 to 256 tokens

REFERENCE_SENTENCES = [
    "pricing table",
    "Plans & Billing\nStarter $29/mo\nPro $79/mo Unlimited seats",
    "Schengen visa rules summary. Applicants must show proof of accommodation.",
    "Rust async notes: tokio runtime, futures, pinning",
    "naïve café résumé — UNICODE test, émojis 🚀 and punctuation!!!",
]


class MeanPooledEncoder(torch.nn.Module):
    """BERT encoder + attention-masked mean pooling + L2 normalisation (as sentence-transformers does)."""

    def __init__(self, bert):
        super().__init__()
        self.bert = bert

    def forward(self, input_ids, attention_mask):
        # Build the attention mask with -1e4 instead of transformers' float32 minimum,
        # which overflows to -inf/NaN once the model runs in float16.
        mask_f = attention_mask.to(torch.float32)
        extended = (1.0 - mask_f[:, None, None, :]) * -1e4
        embeddings = self.bert.embeddings(input_ids=input_ids)
        hidden = self.bert.encoder(embeddings, attention_mask=extended).last_hidden_state
        mask = attention_mask.unsqueeze(-1).to(hidden.dtype)
        summed = (hidden * mask).sum(dim=1)
        counts = mask.sum(dim=1).clamp(min=1e-9)
        pooled = summed / counts
        return torch.nn.functional.normalize(pooled, p=2.0, dim=1)


def main(model_dir: str, out_dir: str) -> None:
    bert = AutoModel.from_pretrained(model_dir, use_safetensors=True, attn_implementation="eager").eval()
    model = MeanPooledEncoder(bert).eval()

    example = (torch.ones(1, 128, dtype=torch.int32), torch.ones(1, 128, dtype=torch.int32))
    traced = torch.jit.trace(model, example, strict=False)

    seq = ct.RangeDim(lower_bound=1, upper_bound=MAX_TOKENS, default=128)
    shapes = ct.Shape(shape=(1, seq))
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=shapes, dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=shapes, dtype=np.int32),
        ],
        outputs=[ct.TensorType(name="embedding")],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.macOS14,
    )
    mlmodel.short_description = "all-MiniLM-L6-v2 sentence embeddings (mean pooled, L2 normalised), 384 dims"
    mlmodel.save(f"{out_dir}/MiniLM.mlpackage")
    shutil.copy(f"{model_dir}/vocab.txt", f"{out_dir}/minilm-vocab.txt")

    # Reference embeddings from the original library, for checking the Swift tokenizer + Core ML model.
    from sentence_transformers import SentenceTransformer

    st = SentenceTransformer(model_dir, device="cpu")
    st.max_seq_length = 256
    ref = st.encode(REFERENCE_SENTENCES, normalize_embeddings=True)
    tok = st.tokenizer
    with open(f"{out_dir}/reference.json", "w") as f:
        json.dump(
            [
                {"text": s, "ids": tok(s, truncation=True, max_length=256)["input_ids"], "embedding": e.tolist()}
                for s, e in zip(REFERENCE_SENTENCES, ref)
            ],
            f,
        )
    print("saved", out_dir)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
