#!/usr/bin/env python3
from __future__ import annotations
import csv, hashlib, io, json, math, urllib.request, warnings
import numpy as np
import statsmodels
from statsmodels.discrete.discrete_model import NegativeBinomialP
from statsmodels.discrete.count_model import ZeroInflatedNegativeBinomialP

SOURCE_BLOB_SHA1='f8040b9c28dff8a70b4918e6033aba7b3d1bf640'
SOURCE_URL='https://raw.githubusercontent.com/DeutscheAktuarvereinigung/WorkingGroup_eXplainableAI_Notebooks/b1c56d0111efc12fe2c63805fc2d555e4da1916e/Reimplementations/Regression/SHAP/SwedishMotorInsurance.csv'
FACTORS=('Kilometres','Zone','Bonus','Make')

def git_blob_sha1(data: bytes)->str:
    return hashlib.sha1(f'blob {len(data)}\0'.encode('ascii')+data).hexdigest()
def load():
    req=urllib.request.Request(SOURCE_URL,headers={'User-Agent':'FFBK-nextgen-research-audit'})
    with urllib.request.urlopen(req,timeout=30) as r: data=r.read()
    if git_blob_sha1(data)!=SOURCE_BLOB_SHA1: raise RuntimeError('source identity mismatch')
    rd=csv.DictReader(io.StringIO(data.decode('utf-8-sig'))); rows=[]
    for raw in rd:
        rows.append({k:int(raw[k]) for k in FACTORS}|{'Insured':float(raw['Insured']),'Claims':int(raw['Claims'])})
    if len(rows)!=2182: raise RuntimeError('row count mismatch')
    return rows
def fold_bucket(row):
    key='|'.join(str(int(row[n])) for n in FACTORS).encode('ascii')
    return int.from_bytes(hashlib.sha256(key).digest()[:8],'big')%5
def training_levels(rows,train):
    return {f:tuple(sorted({int(r[f]) for r,t in zip(rows,train) if t})) for f in FACTORS}
def design(rows,levels):
    cols=['intercept']+[f'{f}={lev}' for f in FACTORS for lev in levels[f][1:]]
    X=np.zeros((len(rows),len(cols))); X[:,0]=1.; c=1
    for f in FACTORS:
        allowed=set(levels[f])
        if any(int(r[f]) not in allowed for r in rows): raise RuntimeError(f'unseen level {f}')
        for lev in levels[f][1:]:
            X[:,c]=[1. if int(r[f])==lev else 0. for r in rows]; c+=1
    return X
def logistic(x): return 1/(1+np.exp(-np.clip(x,-40,40)))
def nb2_logpmf(y,mu,alpha):
    r=1/alpha
    return np.array([math.lgamma(int(yi)+r)-math.lgamma(r)-math.lgamma(int(yi)+1)+int(yi)*math.log(max(alpha*float(mi),1e-300))-(int(yi)+r)*math.log1p(alpha*float(mi)) for yi,mi in zip(y,mu)])
def zinb_logpmf(y,mu,w,alpha):
    main=nb2_logpmf(y,mu,alpha); out=np.log1p(-w)+main; z=y==0
    p0=np.exp(-np.log1p(alpha*mu[z])/alpha); out[z]=np.log(w[z]+(1-w[z])*p0); return out

def main():
    rows=load(); exposure=np.array([r['Insured'] for r in rows]); y=np.array([r['Claims'] for r in rows],dtype=float); fold_id=np.array([fold_bucket(r) for r in rows]); receipts=[]
    oof_nb=np.full(len(rows),np.nan); oof_zi=np.full(len(rows),np.nan)
    for fold in range(5):
        te=fold_id==fold; tr=~te; levels=training_levels(rows,tr); X=design(rows,levels); Xtr,Xte=X[tr],X[te]; ytr,yte=y[tr],y[te]; etr,ete=exposure[tr],exposure[te]
        with warnings.catch_warnings(record=True) as wnb:
            warnings.simplefilter('always')
            nb=NegativeBinomialP(ytr,Xtr,exposure=etr,p=2).fit(method='bfgs',maxiter=500,disp=0)
        with warnings.catch_warnings(record=True) as wzi:
            warnings.simplefilter('always')
            zi=ZeroInflatedNegativeBinomialP(ytr,Xtr,exog_infl=np.ones((tr.sum(),1)),exposure=etr,inflation='logit',p=2).fit(method='bfgs',maxiter=500,disp=0)
        nbp=np.asarray(nb.params); zip_=np.asarray(zi.params); k=X.shape[1]
        nb_alpha=float(nbp[-1]); zi_gamma=float(zip_[0]); zi_alpha=float(zip_[-1])
        if nb_alpha<=0 or zi_alpha<=0: raise RuntimeError(f'nonpositive alpha fold {fold}: {nb_alpha} {zi_alpha}')
        mu_nb=np.exp(np.clip(np.log(ete)+Xte@nbp[:k],-40,40)); mu_zi=np.exp(np.clip(np.log(ete)+Xte@zip_[1:1+k],-40,40)); w=np.full(te.sum(),float(logistic(np.array([zi_gamma]))[0]))
        ll_nb=nb2_logpmf(yte,mu_nb,nb_alpha); ll_zi=zinb_logpmf(yte,mu_zi,w,zi_alpha); oof_nb[te]=ll_nb; oof_zi[te]=ll_zi
        receipts.append({'fold':fold,'n_test':int(te.sum()),'nb_nll':float(-ll_nb.mean()),'zinb_nll':float(-ll_zi.mean()),'zinb_minus_nb2':float((ll_zi-ll_nb).mean()),'nb_alpha':nb_alpha,'zinb_alpha':zi_alpha,'inflate_logit':zi_gamma,'inflate_probability':float(w[0]),'nb_converged':bool(nb.mle_retvals.get('converged',False)),'zinb_converged':bool(zi.mle_retvals.get('converged',False)),'nb_warnings':[str(x.message) for x in wnb],'zinb_warnings':[str(x.message) for x in wzi]})
    out={'status':'STATSMODELS_SWEDISH_ZINB_AUDIT_OK','statsmodels':statsmodels.__version__,'numpy':np.__version__,'source_blob':SOURCE_BLOB_SHA1,'nb2_oof_nll':float(-oof_nb.mean()),'zinb0_oof_nll':float(-oof_zi.mean()),'zinb0_minus_nb2':float((oof_zi-oof_nb).mean()),'positive_folds':sum(r['zinb_minus_nb2']>0 for r in receipts),'folds':receipts}
    print('STATSMODELS_SWEDISH_ZINB_AUDIT_OK '+json.dumps(out,sort_keys=True,separators=(',',':')))
if __name__=='__main__': main()
