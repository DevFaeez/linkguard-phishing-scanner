# Model card — phiusiil-url-lr-v1

## Intended use

Controlled prototype evaluation of URL-based phishing classification. Not qualified as a
standalone consumer protection product. See the actual figures in `reports/training.json`.

## Training

UCI PhiUSIIL dataset, 235,795 source rows. Only the raw `URL` and original `label` are read.
Original label `1` is legitimate; original `0` is phishing. This is explicitly inverted in training.
Conflicting duplicate labels are quarantined. Exact trimmed URL duplicates are removed.
Malformed/unsupported URLs are excluded and counted. No URLs are fetched.

18 lexical features, StandardScaler fitted on training only, LogisticRegression without class
weighting. Registered-domain groups come from tldextract's bundled Public Suffix List, including
private suffixes, with network fetching and disk cache disabled.

GroupShuffleSplit seeds 42/43 produce approximately 70/15/15 train/validation/test, depending on
domain group sizes. Domain overlap is checked with assertions. Threshold selection maximizes
validation recall subject to <=1% validation FPR. No test-driven hyperparameter tuning.

## Interpretation and risks

- Reported precision depends strongly on the dataset's phishing prevalence and is not the
  precision expected in real notifications, where phishing may be rare.
- Historical source collection, URL format or HTTPS distribution may create easy shortcuts.
  High benchmark scores require ablation and independent-source testing before trust.
- No time-based future evaluation, external fresh phishing set, Malaysian traffic benchmark,
  model comparison, probability calibration or adversarial robustness assessment yet.
- URL-only features do not inspect page content, actual ownership, redirects, malware payloads
  or short-link destinations. Benign compromised domains can evade classification.
- Internationalized domains and keywords are observations, not proof of maliciousness.
- The model score is an uncalibrated output. The UI does not claim a probability or safety guarantee.
- Training is binary phishing versus legitimate; it must not be advertised as universal malware detection.

## Export contract

`models/model.json` stores schema version, exact feature order, mean, scale, coefficients,
intercept, threshold, source archive hash and research status. Dart rejects unexpected schemas,
feature order, nonfinite values, invalid scale or unsupported input. Python/Dart golden vectors cover Unicode, emoji, encoded queries, userinfo, IPv6, ports and missing schemes.

Dataset attribution: Prasad, A. & Chandra, S. (2024). PhiUSIIL Phishing URL (Website).
UCI #967. https://doi.org/10.1016/j.cose.2023.103545 . CC BY 4.0.

## QR input (v0.5.0)

Camera/gallery QR is a local input method. A separate Dart ZXing decoder extracts a URL, then
the same frozen lexical URL classifier runs after user confirmation. The phishing model is not
an image classifier and has not been retrained or independently validated for QR campaigns.
QR contents can be dangerous even when decoding succeeds; decoding is not a safety verdict.
