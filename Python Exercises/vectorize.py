from sklearn.feature_extraction.text import TfidfVectorizer
import pandas as pd

def vectorize(docs):
    vectorizer = TfidfVectorizer()
    X = vectorizer.fit_transform(docs)
    tfidf_data = pd.DataFrame(X.toarray(), columns=vectorizer.get_feature_names_out(), index=[f'{i+1}' for i in range(len(docs))])
    return tfidf_data
