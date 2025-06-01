from flask import Flask, request, jsonify
import faiss
import numpy as np
import fitz  # PyMuPDF
import re
import os
from flask_cors import CORS
from sentence_transformers import SentenceTransformer

app = Flask(__name__)
CORS(app)

# ✅ Whitelist of known technical terms
technical_keywords = {
    'html', 'css', 'sass', 'javascript', 'es6', 'node', 'nodejs', 'express', 'expressjs',
    'react', 'reactjs', 'redux', 'jest', 'thunk', 'mssql', 'mysql', 'mongodb', 'nosql',
    'rest', 'restful', 'api', 'apis', 'aws', 'gcp', 'azure', 'heroku', 'docker', 'kubernetes',
    'git', 'github', 'gitlab', 'oop', 'object', 'oriented', 'functional', 'programming',
    'testing', 'ci', 'cd', 'pipeline', 'pipelines', 'devops',
    'containerization', 'microservices', 'flask', 'django', 'streamlit', 'panel', 'python',
    'sql', 'typescript', 'cloud', 'linux', 'bash', 'power bi', 'c++', 'c#', 'java', 'spring',
    'springboot', 'graphql', 'postgre', 'postgresql', 'vue', 'vuejs', 'angular', 'tailwind',
    'materialui', 'bootstrap', 'vite', 'webpack', 'terraform', 'ansible', 'jenkins', 'circleci',
    'redux-saga', 'nextjs', 'nuxtjs', 'vitepress', 'junit', 'mocha', 'chai', 'pytest',
    'unittest', 'selenium', 'cypress', 'playwright', 'llm', 'openai', 'gemini', 'langchain',
    'minilm', 'bert', 'transformers', 'huggingface', 'faiss', 'sagemaker', 'pytorch',
    'tensorflow', 'keras', 'xgboost', 'scikit-learn', 'numpy', 'pandas', 'matplotlib', 'seaborn',
    'plotly', 'datawrangler', 'mlflow', 'kubeflow', 'spacy', 'nltk', 'keybert', 'pdfkit',
    'reportlab', 'jupyter', 'colab', 'bigquery', 'snowflake', 'redshift', 'looker', 'tableau',
    'powerbi', 'dax', 'etl', 'eda', 'datawarehouse', 'wireframing', 'prototyping', 'usability',
    'ui', 'ux', 'uxdesign', 'figma', 'sketch', 'adobexd', 'invision', 'journeymapping',
    'abtesting', 'wcag', 'accessibility', 'typography', 'persona', 'zerotrust', 'soc2', 'iam',
    'firewall', 'vpn', 'splunk', 'snort', 'wireshark', 'nmap', 'owasp', 'guardduty',
    'cloudtrail', 'waf', 'kms', 'hashicorp', 'vault', 'incident', 'response', 'penetration',
    'vulnerability', 'compliance', 'gdpr', 'iso27001', 'net', 'sdlc', 'redis', 'c#', 'csharp'
}

# ✅ Mapping for frontend-friendly display
display_map = {
    'net': '.NET',
    'c#': 'C#',
    'c++': 'C++',
}

# ✅ Tokenizer with normalization
def clean_and_tokenize(text):
    text = text.replace('C#', 'c#').replace('C++', 'c++').replace('.NET', 'net')
    words = re.findall(r'\b[\w#+.]+\b', text.lower())
    normalized_words = set(w.strip(".").strip(",") for w in words)
    print("🔍 Extracted words from input text:", normalized_words)
    print("🧠 Matched technical keywords:", normalized_words & technical_keywords)
    return set(w for w in normalized_words if w in technical_keywords)

# ✅ Load models and data
model = SentenceTransformer('all-MiniLM-L6-v2')
index = faiss.read_index('faiss_job_index.index')
job_embeddings = np.load('job_embeddings.npy')
with open('job_descriptions.txt', 'r') as f:
    job_descriptions = [line.strip() for line in f if line.strip()]

def extract_text_from_pdf(pdf_path):
    doc = fitz.open(pdf_path)
    text = ''.join([page.get_text() for page in doc])
    return text.strip()

@app.route('/analyze', methods=['POST'])
def analyze_resume():
    if 'resume' not in request.files:
        return jsonify({"error": "Resume file missing"}), 400

    file = request.files['resume']
    if not file.filename.endswith('.pdf'):
        return jsonify({"error": "Only PDF resumes are supported"}), 400

    temp_path = '/tmp/temp_resume.pdf'
    file.save(temp_path)
    resume_text = extract_text_from_pdf(temp_path)
    os.remove(temp_path)

    user_jd = request.form.get('jobdesc', '').strip()

    if user_jd:
        jd_embedding = model.encode([user_jd])
        resume_embedding = model.encode([resume_text])
        matched_description = user_jd
        dot = np.dot(resume_embedding, jd_embedding.T)
        norm = np.linalg.norm(resume_embedding) * np.linalg.norm(jd_embedding)
        similarity_score = float(dot / norm)
    else:
        resume_embedding = model.encode([resume_text])
        D, I = index.search(resume_embedding, k=1)
        best_match_idx = I[0][0]
        matched_description = job_descriptions[best_match_idx]
        similarity_score = 1 / (1 + D[0][0])

    jd_keywords = clean_and_tokenize(matched_description)
    resume_keywords = clean_and_tokenize(resume_text)
    common = jd_keywords & resume_keywords
    missing = jd_keywords - resume_keywords
    keyword_match_percentage = (len(common) / len(jd_keywords)) * 100 if jd_keywords else 0

    # 🔁 Display-friendly keywords
    display_missing = [display_map.get(w, w) for w in missing]

    return jsonify({
        "job_description_used": matched_description,
        "similarity_score": float(round(similarity_score, 2)),
        "keyword_match_percent": float(round(keyword_match_percentage, 2)),
        "keywords_matched": len(common),
        "total_keywords": len(jd_keywords),
        "recognized_keywords": sorted(list(jd_keywords)),
        "missing_keywords": sorted(list(missing))
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
