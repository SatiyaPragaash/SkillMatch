from sentence_transformers import SentenceTransformer
import faiss
import numpy as np

# Load job descriptions
with open('job_descriptions.txt', 'r') as f:
    job_descriptions = [line.strip() for line in f if line.strip()]

# Load embedding model
model = SentenceTransformer('all-MiniLM-L6-v2')
job_embeddings = model.encode(job_descriptions)

# Save for reuse
np.save('job_embeddings.npy', job_embeddings)

# Create FAISS index
dimension = job_embeddings.shape[1]
index = faiss.IndexFlatL2(dimension)
index.add(np.array(job_embeddings))

# Save FAISS index
faiss.write_index(index, 'faiss_job_index.index')

print(f"Indexed {len(job_descriptions)} job descriptions.")
