#!/usr/bin/env python3
from __future__ import annotations
import csv, hashlib, io, json, math, urllib.request
from dataclasses import dataclass
import numpy as np

SOURCE_BLOB_SHA1='f8040b9c28dff8a70b4918e6033aba7b3d1bf640'
SOURCE_ROWS=2182
SOURCE_URLS=(
'https://raw.githubusercontent.com/DeutscheAktuarvereinigung/WorkingGroup_eXplainableAI_Notebooks/b1c56d0111efc12fe2c63805fc2d555e4da1916e/Reimplementations/Regression/SHAP/SwedishMotorInsurance.csv',
'https://raw.githubusercontent.com/OpenActTextDev/ActuarialRegression/185104a4c665da0357123d935ad169f6af8b02be/CSVData/SwedishMotorInsurance.csv')
EXPECTED_HEADER=('Kilometres','Zone','Bonus','Make','Insured','Claims','Payment')
FACTORS=('Kilometres','Zone','Bonus','Make')
HOLDOUT_MODULUS=5
ALPHA_MIN=1e-8; ALPHA_MAX=10.0; ZI_STARTS=(1e-8,0.02,0.10,0.30)

@dataclass(frozen=True)
class Fit:
    beta: np.ndarray; mu: np.ndarray; iterations: int
@dataclass(frozen=True)
class NB2Fit:
    alpha: float; beta: np.ndarray; mu: np.ndarray; loglik: float

def git_blob_sha1(data: bytes)->str:
    return hashlib.sha1(f'blob {len(data)}\0'.encode('ascii')+data).hexdigest()
def load_source_bytes():
    errors=[]
    for url in SOURCE_URLS:
        try:
            req=urllib.request.Request(url,headers={'User-Agent':'FFBK-nextgen-research'})
            with urllib.request.urlopen(req,timeout=30) as r: data=r.read()
        except Exception as exc:
            errors.append(f'{url}:{type(exc).__name__}:{exc}'); continue
        actual=git_blob_sha1(data)
        if actual != SOURCE_BLOB_SHA1:
            errors.append(f'{url}:blob {actual} != {SOURCE_BLOB_SHA1}'); continue
        return data,url
    raise RuntimeError('unable to fetch verified Swedish Motor CSV: '+' | '.join(errors))
def parse_rows(data):
    reader=csv.DictReader(io.StringIO(data.decode('utf-8-sig')))
    if tuple(reader.fieldnames or ()) != EXPECTED_HEADER: raise ValueError(reader.fieldnames)
    rows=[]
    for raw in reader:
        row={'Kilometres':int(raw['Kilometres']),'Zone':int(raw['Zone']),'Bonus':int(raw['Bonus']),'Make':int(raw['Make']),'Insured':float(raw['Insured']),'Claims':int(raw['Claims']),'Payment':float(raw['Payment'])}
        if row['Insured']<=0 or row['Claims']<0 or row['Payment']<0: raise ValueError('invalid row')
        rows.append(row)
    if len(rows)!=SOURCE_ROWS: raise ValueError(len(rows))
    return rows
def fold_bucket(row,modulus=HOLDOUT_MODULUS):
    key='|'.join(str(int(row[name])) for name in FACTORS).encode('ascii')
    return int.from_bytes(hashlib.sha256(key).digest()[:8],'big')%modulus
def training_levels(rows,train):
    out={}
    for f in FACTORS:
        vals=sorted({int(r[f]) for r,t in zip(rows,train) if t})
        if len(vals)<2: raise ValueError(f)
        out[f]=tuple(vals)
    return out
def design_matrix(rows,levels):
    columns=['intercept']
    for f in FACTORS: columns.extend(f'{f}={lev}' for lev in levels[f][1:])
    X=np.zeros((len(rows),len(columns))); X[:,0]=1.; col=1
    for f in FACTORS:
        allowed=set(levels[f])
        for r in rows:
            if int(r[f]) not in allowed: raise ValueError(f'unseen {f}={r[f]}')
        for lev in levels[f][1:]:
            X[:,col]=[1. if int(r[f])==lev else 0. for r in rows]; col+=1
    return X,columns
def wls(X,target,weights):
    root=np.sqrt(np.maximum(weights,1e-15)); beta,*_=np.linalg.lstsq(X*root[:,None],target*root,rcond=None); return beta
def safe_exp(x): return np.exp(np.clip(x,-30.,30.))
def fit_poisson(X,y,exposure,max_iter=100,tol=1e-10,initial=None):
    offset=np.log(exposure)
    if initial is None:
        beta=np.zeros(X.shape[1]); beta[0]=math.log(max(float(y.sum())/float(exposure.sum()),1e-12))
    else: beta=np.array(initial,dtype=float,copy=True)
    for iteration in range(1,max_iter+1):
        eta=offset+X@beta; mu=safe_exp(eta); z=eta+(y-mu)/np.maximum(mu,1e-15); updated=wls(X,z-offset,mu)
        if np.max(np.abs(updated-beta))<tol: beta=updated; break
        beta=updated
    else: raise RuntimeError('Poisson IRLS did not converge')
    return Fit(beta,safe_exp(offset+X@beta),iteration)
def fit_nb2_given_alpha(X,y,exposure,alpha,initial=None,max_iter=100,tol=1e-10):
    offset=np.log(exposure)
    if initial is None: initial=fit_poisson(X,y,exposure).beta
    beta=np.array(initial,dtype=float,copy=True)
    for iteration in range(1,max_iter+1):
        eta=offset+X@beta; mu=safe_exp(eta); z=eta+(y-mu)/np.maximum(mu,1e-15); weights=mu/(1.+alpha*mu); updated=wls(X,z-offset,weights)
        if np.max(np.abs(updated-beta))<tol: beta=updated; break
        beta=updated
    else: raise RuntimeError('NB2 IRLS did not converge')
    return Fit(beta,safe_exp(offset+X@beta),iteration)
def nb2_logpmf(y,mu,alpha):
    r=1./alpha
    return np.array([math.lgamma(int(yi)+r)-math.lgamma(r)-math.lgamma(int(yi)+1.)+int(yi)*math.log(max(alpha*float(mi),1e-300))-(int(yi)+r)*math.log1p(alpha*float(mi)) for yi,mi in zip(y,mu)])
def poisson_logpmf(y,mu):
    return np.array([int(yi)*math.log(max(float(mi),1e-300))-float(mi)-math.lgamma(int(yi)+1.) for yi,mi in zip(y,mu)])
def nb2_loglik(y,mu,alpha): return float(np.sum(nb2_logpmf(y,mu,alpha)))
def moment_alpha(y,mu):
    d=float(np.sum(mu**2)); n=float(np.sum((y-mu)**2-y)); return 1e-6 if d<=0 else min(10.,max(1e-8,n/d))
def fit_nb2_profile(X,y,exposure):
    pois=fit_poisson(X,y,exposure); mom=moment_alpha(y,pois.mu); center=math.log(max(mom,1e-5)); low=max(math.log(1e-8),center-math.log(100.)); high=min(math.log(10.),center+math.log(100.)); grid=np.linspace(low,high,25); cache={}
    def eval_(la):
        key=float(la)
        if key not in cache:
            a=math.exp(key); f=fit_nb2_given_alpha(X,y,exposure,a,initial=pois.beta); cache[key]=(f,nb2_loglik(y,f.mu,a))
        return cache[key]
    scored=[(float(g),eval_(float(g))[1]) for g in grid]; bi=max(range(len(scored)),key=lambda i: scored[i][1])
    if bi==0: a,b=low,float(grid[1])
    elif bi==len(grid)-1: a,b=float(grid[-2]),high
    else: a,b=float(grid[bi-1]),float(grid[bi+1])
    phi=(1+math.sqrt(5))/2; c=b-(b-a)/phi; d=a+(b-a)/phi; fc=eval_(c)[1]; fd=eval_(d)[1]
    for _ in range(22):
        if fc>fd: b,d,fd=d,c,fc; c=b-(b-a)/phi; fc=eval_(c)[1]
        else: a,c,fc=c,d,fd; d=a+(b-a)/phi; fd=eval_(d)[1]
    best=(a+b)/2; f,ll=eval_(best); alpha=math.exp(best)
    ba=1e-8; bf=fit_nb2_given_alpha(X,y,exposure,ba,initial=pois.beta); bll=nb2_loglik(y,bf.mu,ba)
    return NB2Fit(ba,bf.beta,bf.mu,bll) if bll>ll else NB2Fit(alpha,f.beta,f.mu,ll)
def predict_mu(X,exposure,beta): return safe_exp(np.log(exposure)+X@beta)
def logistic(x):
    out=np.empty_like(x,dtype=float); pos=x>=0; out[pos]=1/(1+np.exp(-x[pos])); ex=np.exp(x[~pos]); out[~pos]=ex/(1+ex); return np.clip(out,1e-12,1-1e-12)
def weighted_count_fit(X,y,exposure,q,alpha,initial):
    beta=np.array(initial,dtype=float,copy=True); offset=np.log(exposure)
    for _ in range(100):
        eta=offset+X@beta; mu=safe_exp(eta); z=eta+(y-mu)/np.maximum(mu,1e-15); weights=q*mu if alpha is None else q*mu/(1+alpha*mu); updated=wls(X,z-offset,weights)
        if np.max(np.abs(updated-beta))<1e-10: beta=updated; break
        beta=updated
    else: raise RuntimeError('weighted count IRLS did not converge')
    return beta,safe_exp(offset+X@beta)
def main_zero_probability(mu,alpha):
    return np.exp(-mu) if alpha is None or alpha<=1e-7 else np.exp(-np.log1p(alpha*mu)/alpha)
def zi_logpmf(y,mu,w,alpha):
    main=poisson_logpmf(y,mu) if alpha is None else nb2_logpmf(y,mu,alpha); out=np.log1p(-w)+main; zero=y==0; p0=main_zero_probability(mu[zero],alpha); out[zero]=np.log(w[zero]+(1-w[zero])*p0); return out
def fit_fractional_logit(Z,tau,initial):
    gamma=np.array(initial,dtype=float,copy=True)
    for _ in range(100):
        eta=np.clip(Z@gamma,-30.,30.); p=logistic(eta); weights=np.maximum(p*(1-p),1e-9); updated=np.clip(wls(Z,eta+(tau-p)/weights,weights),-30.,30.)
        if np.max(np.abs(updated-gamma))<1e-9: return updated
        gamma=updated
    return gamma
def optimize_alpha(y,mu,q,current):
    low,high=math.log(ALPHA_MIN),math.log(ALPHA_MAX); grid=sorted(set(np.linspace(low,high,17).tolist()+[math.log(current)]))
    def sc(la): return float(np.sum(q*nb2_logpmf(y,mu,math.exp(la))))
    vals=[sc(g) for g in grid]; best=max(range(len(grid)),key=lambda i:vals[i]); a=grid[max(0,best-1)]; b=grid[min(len(grid)-1,best+1)]
    if a==b: return math.exp(grid[best])
    phi=(1+math.sqrt(5))/2; c,d=b-(b-a)/phi,a+(b-a)/phi; fc,fd=sc(c),sc(d)
    for _ in range(24):
        if fc>fd: b,d,fd=d,c,fc; c=b-(b-a)/phi; fc=sc(c)
        else: a,c,fc=c,d,fd; d=a+(b-a)/phi; fd=sc(d)
    cand=(ALPHA_MIN,math.exp((a+b)/2),math.exp(grid[best]),ALPHA_MAX)
    return max(cand,key=lambda x:float(np.sum(q*nb2_logpmf(y,mu,x))))
def fit_zi(X,Z,y,exposure,alpha0,beta0,start_w):
    alpha=alpha0; beta=np.array(beta0,copy=True); gamma=np.zeros(Z.shape[1]); gamma[0]=math.log(start_w/(1-start_w)); prev=-math.inf; converged=False
    for iteration in range(1,241):
        mu=predict_mu(X,exposure,beta); w=logistic(Z@gamma); p0=main_zero_probability(mu,alpha); tau=np.zeros_like(y); zero=y==0; tau[zero]=w[zero]/np.maximum(w[zero]+(1-w[zero])*p0[zero],1e-300); q=1-tau
        gamma=fit_fractional_logit(Z,tau,gamma); beta,mu=weighted_count_fit(X,y,exposure,q,alpha,beta)
        if alpha is not None: alpha=optimize_alpha(y,mu,q,alpha); beta,mu=weighted_count_fit(X,y,exposure,q,alpha,beta)
        w=logistic(Z@gamma); ll=float(np.sum(zi_logpmf(y,mu,w,alpha)))
        if ll+1e-7<prev: raise RuntimeError(f'ZI observed loglik decreased: {prev}->{ll}')
        if math.isfinite(prev) and abs(ll-prev)<1e-7*(1+abs(prev)): converged=True; break
        prev=ll
    return {'beta':beta,'gamma':gamma,'alpha':alpha,'mu':predict_mu(X,exposure,beta),'w':logistic(Z@gamma),'loglik':float(np.sum(zi_logpmf(y,predict_mu(X,exposure,beta),logistic(Z@gamma),alpha))),'iterations':iteration,'converged':converged}
def best_zi(X,Z,y,exposure,alpha0,beta0):
    fits=[]; errors=[]
    for st in ZI_STARTS:
        try: fits.append(fit_zi(X,Z,y,exposure,alpha0,beta0,st))
        except Exception as exc: errors.append(f'{st}:{type(exc).__name__}:{exc}')
    conv=[f for f in fits if bool(f['converged'])]
    if not conv: raise RuntimeError('no converged ZI fit: '+' | '.join(errors))
    return max(conv,key=lambda f:float(f['loglik']))
def score(y,mu,alpha,w):
    if w is None:
        ll=poisson_logpmf(y,mu) if alpha is None else nb2_logpmf(y,mu,alpha); p0=main_zero_probability(mu,alpha)
    else: ll=zi_logpmf(y,mu,w,alpha); p0=w+(1-w)*main_zero_probability(mu,alpha)
    return ll,p0
def predictive_mean(mu,w): return mu if w is None else (1-w)*mu
def run():
    data,source=load_source_bytes(); rows=parse_rows(data); exposure=np.array([float(r['Insured']) for r in rows]); y=np.array([float(r['Claims']) for r in rows]); loge=np.log(exposure); fold_id=np.array([fold_bucket(r) for r in rows]); cuts=np.quantile(exposure,[.2,.4,.6,.8]); quint=np.searchsorted(cuts,exposure,side='right')
    names=('poisson','nb2','zip0','zinb0','zinb_e'); oof_ll={n:np.full(len(rows),np.nan) for n in names}; oof_p0={n:np.full(len(rows),np.nan) for n in names}; oof_mu={n:np.full(len(rows),np.nan) for n in names}; folds=[]
    for fold in range(HOLDOUT_MODULUS):
        test=fold_id==fold; train=~test; levels=training_levels(rows,train); X,cols=design_matrix(rows,levels); Xtr,Xte=X[train],X[test]; ytr,yte=y[train],y[test]; etr,ete=exposure[train],exposure[test]
        pois=fit_poisson(Xtr,ytr,etr); nb=fit_nb2_profile(Xtr,ytr,etr); z0tr=np.ones((train.sum(),1)); z0te=np.ones((test.sum(),1)); m,s=float(np.mean(loge[train])),float(np.std(loge[train])); ze_tr=np.column_stack((np.ones(train.sum()),(loge[train]-m)/s)); ze_te=np.column_stack((np.ones(test.sum()),(loge[test]-m)/s))
        zip0=best_zi(Xtr,z0tr,ytr,etr,None,pois.beta); zinb0=best_zi(Xtr,z0tr,ytr,etr,nb.alpha,nb.beta); zinbe=best_zi(Xtr,ze_tr,ytr,etr,nb.alpha,nb.beta)
        specs={'poisson':(pois.beta,None,None,None,None),'nb2':(nb.beta,nb.alpha,None,None,None),'zip0':(zip0['beta'],None,zip0['gamma'],z0te,zip0),'zinb0':(zinb0['beta'],zinb0['alpha'],zinb0['gamma'],z0te,zinb0),'zinb_e':(zinbe['beta'],zinbe['alpha'],zinbe['gamma'],ze_te,zinbe)}
        rec={'fold':fold,'parameter_count':len(cols),'n_test':int(test.sum())}
        for name,(beta,alpha,gamma,Zte,fitrec) in specs.items():
            mu=predict_mu(Xte,ete,beta); w=None if gamma is None else logistic(Zte@gamma); ll,p0=score(yte,mu,alpha,w); mean=predictive_mean(mu,w); oof_ll[name][test]=ll; oof_p0[name][test]=p0; oof_mu[name][test]=mean
            rec[name]={'nll':float(-np.mean(ll)),'zero_brier':float(np.mean(((yte==0)-p0)**2)),'alpha':None if alpha is None else float(alpha),'gamma':None if gamma is None else [float(v) for v in gamma],'converged':True if fitrec is None else bool(fitrec['converged']),'iterations':int(pois.iterations) if name=='poisson' else None if fitrec is None else int(fitrec['iterations']),'train_loglik':float(np.sum(poisson_logpmf(ytr,pois.mu))) if name=='poisson' else float(nb.loglik) if name=='nb2' else float(fitrec['loglik']),'test_zero_probability_min':float(np.min(p0)),'test_zero_probability_max':float(np.max(p0)),'test_mean_sum':float(np.sum(mean)),'test_zero_mixture_min':None if w is None else float(np.min(w)),'test_zero_mixture_max':None if w is None else float(np.max(w))}
        rec['zinb0_minus_nb2']=float(np.mean(oof_ll['zinb0'][test]-oof_ll['nb2'][test])); rec['zip0_minus_poisson']=float(np.mean(oof_ll['zip0'][test]-oof_ll['poisson'][test])); rec['zinbe_minus_zinb0']=float(np.mean(oof_ll['zinb_e'][test]-oof_ll['zinb0'][test])); folds.append(rec)
    zero=(y==0).astype(float); aggregate={}
    for name in names:
        qdiag=[]
        for q in range(5):
            idx=quint==q; qdiag.append({'q':q+1,'n':int(idx.sum()),'obs':float(np.mean(zero[idx])),'pred':float(np.mean(oof_p0[name][idx]))})
        aggregate[name]={'oof_nll':float(-np.mean(oof_ll[name])),'zero_brier':float(np.mean((zero-oof_p0[name])**2)),'predicted_zero':float(np.mean(oof_p0[name])),'ae_count':float(np.sum(y)/np.sum(oof_mu[name])),'zero_by_exposure_quintile':qdiag}
    pf=[float(f['zinb0_minus_nb2']) for f in folds]; zf=[float(f['zip0_minus_poisson']) for f in folds]; ef=[float(f['zinbe_minus_zinb0']) for f in folds]
    return {'status':'SWEDISH_MOTOR_ZERO_INFLATION_OK','source':{'selected':source,'git_blob_sha1':git_blob_sha1(data),'rows':len(rows)},'zero_cells':int(np.sum(y==0)),'zero_share':float(np.mean(y==0)),'aggregate':aggregate,'folds':folds,'primary':{'zinb0_minus_nb2':float(np.mean(oof_ll['zinb0']-oof_ll['nb2'])),'positive_folds':int(sum(v>0 for v in pf)),'fold_deltas':pf,'zero_brier_delta':float(aggregate['zinb0']['zero_brier']-aggregate['nb2']['zero_brier'])},'secondary':{'zip0_minus_poisson':float(np.mean(oof_ll['zip0']-oof_ll['poisson'])),'zip_positive_folds':int(sum(v>0 for v in zf)),'zinbe_minus_zinb0':float(np.mean(oof_ll['zinb_e']-oof_ll['zinb0'])),'zinbe_positive_folds':int(sum(v>0 for v in ef))}}
if __name__=='__main__':
    res=run()
    if res['source']['git_blob_sha1']!=SOURCE_BLOB_SHA1 or res['source']['rows']!=SOURCE_ROWS: raise SystemExit('source identity failed')
    print('SWEDISH_MOTOR_ZERO_INFLATION_OK '+json.dumps(res,sort_keys=True,separators=(',',':')))
