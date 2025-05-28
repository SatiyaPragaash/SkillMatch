import faiss
import numpy as np
import fitz  # PyMuPDF
import re
from sentence_transformers import SentenceTransformer

# ✅ Define whitelist of known technical keywords
technical_keywords = {
    'html', 'css', 'sass', 'javascript', 'es6', 'node', 'nodejs', 'express', 'expressjs',
    'react', 'reactjs', 'redux', 'jest', 'thunk', 'mssql', 'mysql', 'mongodb', 'nosql',
    'rest', 'restful', 'api', 'apis', 'aws', 'gcp', 'azure', 'heroku', 'docker', 'kubernetes',
    'git', 'github', 'gitlab', 'oop', 'object', 'oriented', 'functional', 'programming',
    'testing', 'state', 'command', 'line', 'ci', 'cd', 'pipeline', 'pipelines', 'devops',
    'containerization', 'microservices', 'flask', 'django', 'streamlit', 'panel', 'python',
    'sql', 'typescript', 'cloud', 'linux', 'bash',
    'c++', 'c#', 'typescript', 'java', 'spring', 'springboot', 'graphql', 'postgre', 'postgresql',
    'vue', 'vuejs', 'angular', 'tailwind', 'materialui', 'bootstrap', 'vite', 'webpack',
    'terraform', 'ansible', 'jenkins', 'circleci', 'redux-saga', 'nextjs', 'nuxtjs', 'vitepress',
    'junit', 'mocha', 'chai', 'pytest', 'unittest', 'selenium', 'cypress', 'playwright',
    'llm', 'openai', 'gemini', 'langchain', 'minilm', 'bert', 'transformers', 'huggingface',
    'faiss', 'sagemaker', 'pytorch', 'tensorflow', 'keras', 'xgboost', 'scikit-learn', 'numpy',
    'pandas', 'matplotlib', 'seaborn', 'plotly', 'datawrangler', 'mlflow', 'kubeflow',
    'spacy', 'nltk', 'keybert', 'pdfkit', 'reportlab', 'jupyter', 'colab', 'bigquery',
    'snowflake', 'redshift', 'looker', 'tableau', 'powerbi', 'dax', 'etl', 'eda', 'datawarehouse',
    'wireframing', 'prototyping', 'usability', 'ui', 'ux', 'uxdesign', 'figma', 'sketch',
    'adobexd', 'invision', 'journeymapping', 'abtesting', 'wcag', 'accessibility', 'typography',
    'persona', 'zerotrust', 'soc2', 'iam', 'firewall', 'vpn', 'splunk', 'snort', 'wireshark',
    'nmap', 'owasp', 'guardduty', 'cloudtrail', 'waf', 'kms', 'hashicorp', 'vault', 'incident',
    'response', 'penetration', 'vulnerability', 'compliance', 'gdpr', 'iso27001'
}


# ✅ Clean and tokenize using whitelist
def clean_and_tokenize(text):
    words = re.findall(r'\b\w+\b', text.lower())
    return set(w for w in words if w in technical_keywords)

# Load job descriptions (for fallback mode)
with open('job_descriptions.txt', 'r') as f:
    job_descriptions = [line.strip() for line in f if line.strip()]

# Load model
model = SentenceTransformer('all-MiniLM-L6-v2')

# Load FAISS index and embeddings
index = faiss.read_index('faiss_job_index.index')
job_embeddings = np.load('job_embeddings.npy')

# Extract text from PDF resume
def extract_text_from_pdf(pdf_path):
    doc = fitz.open(pdf_path)
    text = ''
    for page in doc:
        text += page.get_text()
    return text.strip()

resume_text = extract_text_from_pdf('sample_resume.pdf')

# Prompt user for job description (multi-line)
print("\n📋 Paste job description (multi-line). Press Enter on a blank line to finish:")
custom_lines = []
while True:
    line = input()
    if line.strip() == "":
        break
    custom_lines.append(line.strip())

custom_jd = " ".join(custom_lines)

# 🔹 Custom JD path
if custom_jd:
    jd_embedding = model.encode([custom_jd])
    resume_embedding = model.encode([resume_text])
    matched_description = custom_jd
    dot = np.dot(resume_embedding, jd_embedding.T)
    norm = np.linalg.norm(resume_embedding) * np.linalg.norm(jd_embedding)
    similarity_score = float(dot / norm)
else:
    resume_embedding = model.encode([resume_text])
    D, I = index.search(resume_embedding, k=1)
    best_match_idx = I[0][0]
    matched_description = job_descriptions[best_match_idx]
    similarity_score = 1 / (1 + D[0][0])

# 🔹 Keyword comparison
jd_keywords = clean_and_tokenize(matched_description)
resume_keywords = clean_and_tokenize(resume_text)
common = jd_keywords & resume_keywords
missing = jd_keywords - resume_keywords
keyword_match_percentage = (len(common) / len(jd_keywords)) * 100 if jd_keywords else 0

# 🔹 Final Output
print("\n📝 Job Description Used:")
print(matched_description)
print(f"\n✅ Similarity Score: {similarity_score:.2f}")
print(f"📊 Keyword Match: {keyword_match_percentage:.2f}%")
print("\n🔍 Missing technical keywords from resume:")
print(", ".join(list(missing)[:10]) or "None — Good match!")
