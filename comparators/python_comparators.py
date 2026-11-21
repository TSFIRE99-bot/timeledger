"""Run established non-R event-scoring toolkits on the 100-minute acceptance
fixture and record what each can and cannot express.

Toolkits: timescoring (SzCORE seizure scoring), sed_eval (DCASE sound event
detection), and the CPSC 2021 sample scorer (score_2021.py).

Usage: python comparators/python_comparators.py <site-packages dir> <out.json>
"""
import json
import os
import sys
import tempfile
import traceback

sys.path.insert(0, sys.argv[1])
out_path = sys.argv[2]

import numpy as np  # noqa: E402
import importlib.metadata as md  # noqa: E402

MIN = 60.0
T = 100 * MIN
REF_AF = [(10 * MIN, 20 * MIN), (40 * MIN, 60 * MIN)]
FLAG = [(10 * MIN, 20 * MIN), (70 * MIN, 80 * MIN)]
ABSTAIN = [(40 * MIN, 60 * MIN)]
results = {"versions": {"python": sys.version.split()[0], "numpy": np.__version__}}

# --- timescoring -----------------------------------------------------------
try:
    from timescoring.annotations import Annotation
    from timescoring import scoring

    results["versions"]["timescoring"] = md.version("timescoring")
    fs = 1
    ref = Annotation(REF_AF, fs, int(T))
    hyp = Annotation(FLAG, fs, int(T))  # abstention has no representation
    ss = scoring.SampleScoring(ref, hyp)
    param = scoring.EventScoring.Parameters(toleranceStart=0, toleranceEnd=0,
                                            minOverlap=0, maxEventDuration=1e9,
                                            minDurationBetweenEvents=0)
    es = scoring.EventScoring(ref, hyp, param)
    es_default = scoring.EventScoring(ref, hyp)
    results["timescoring"] = {
        "abstention_representable": False,
        "note": "Hypotheses are a set of event intervals over the whole recording; "
                "abstained time can only be scored as 'no event'.",
        "sample_sensitivity": ss.sensitivity, "sample_precision": ss.precision,
        "event_sensitivity": es.sensitivity, "event_precision": es.precision,
        "event_fp": int(es.fp), "event_fp_per_day": es.fpRate,
        "fp_rate_denominator_hours": T / 3600,
        "default_params_event_sensitivity": es_default.sensitivity,
        "default_params_fp": int(es_default.fp),
    }
except Exception:
    results["timescoring"] = {"error": traceback.format_exc()}

# --- sed_eval ----------------------------------------------------------------
try:
    import warnings
    warnings.filterwarnings("ignore")
    import sed_eval
    import dcase_util

    results["versions"]["sed_eval"] = md.version("sed_eval")
    ref_list = dcase_util.containers.MetaDataContainer(
        [{"filename": "rec1", "event_label": "AF", "onset": a, "offset": b}
         for a, b in REF_AF])
    est_list = dcase_util.containers.MetaDataContainer(
        [{"filename": "rec1", "event_label": "AF", "onset": a, "offset": b}
         for a, b in FLAG])
    seg = sed_eval.sound_event.SegmentBasedMetrics(event_label_list=["AF"],
                                                   time_resolution=MIN)
    seg.evaluate(reference_event_list=ref_list, estimated_event_list=est_list)
    ev = sed_eval.sound_event.EventBasedMetrics(event_label_list=["AF"],
                                                t_collar=0.001,  # must be > 0 in sed_eval
                                                percentage_of_length=0.0)
    ev.evaluate(reference_event_list=ref_list, estimated_event_list=est_list)
    so = seg.results_overall_metrics()
    eo = ev.results_overall_metrics()
    results["sed_eval"] = {
        "abstention_representable": False,
        "note": "Segment metrics are computed over segments spanned by the reference "
                "and estimate lists; there is no per-system scored region.",
        "segment_recall": so["f_measure"]["recall"],
        "segment_precision": so["f_measure"]["precision"],
        "event_recall": eo["f_measure"]["recall"],
        "event_precision": eo["f_measure"]["precision"],
    }
except Exception:
    results["sed_eval"] = {"error": traceback.format_exc()}

# --- CPSC 2021 sample scorer ---------------------------------------------------
try:
    import wfdb
    results["versions"]["wfdb"] = md.version("wfdb")
    here = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, os.path.join(here, "..", "audit", "sources"))
    import score_2021 as cpsc

    tmp = tempfile.mkdtemp()
    fs = 200
    n = int(T / MIN * 60 * fs) // 20  # short synthetic record (5 min at 200 Hz)
    sig = np.random.default_rng(1).normal(size=(n, 1))
    wfdb.wrsamp("s1", fs=fs, units=["mV"], sig_name=["I"], p_signal=sig,
                write_dir=tmp, comments=["paroxysmal atrial fibrillation"])
    beats = np.arange(100, n - 100, 160)
    aux = [""] * len(beats)
    sym = ["N"] * len(beats)
    k1, k2 = 300, 600
    i1 = int(np.searchsorted(beats, k1 * fs // 10))
    i2 = int(np.searchsorted(beats, k2 * fs // 10))
    sym[i1], aux[i1] = "+", "(AFL"
    sym[i2], aux[i2] = "+", "(N"
    wfdb.wrann("s1", "atr", beats, symbol=sym, aux_note=aux, write_dir=tmp)
    try:
        ref = cpsc.RefInfo(os.path.join(tmp, "s1"))
        results["cpsc2021"] = {"ran": True, "class_true": int(ref.class_true)}
    except Exception as e:
        results["cpsc2021"] = {
            "ran": False, "error_type": type(e).__name__, "error": str(e),
            "note": "score_2021.py uses np.float, removed in NumPy 1.24; the "
                    "scorer as distributed fails on any AF record with current NumPy.",
        }
    results["cpsc2021"]["abstention_representable"] = False
    results["cpsc2021"]["design"] = ("Scores onset/offset positions within beat "
                                     "tolerances and a record-level class; AF and AFL "
                                     "are pooled; no notion of unanswered time.")
except Exception:
    results["cpsc2021"] = {"error": traceback.format_exc()}

with open(out_path, "w") as f:
    json.dump(results, f, indent=2, default=float)
print(json.dumps(results, indent=2, default=float))
