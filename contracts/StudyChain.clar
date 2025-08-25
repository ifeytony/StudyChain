;; StudyChain: Academic Learning and Progress Reward System
;; Version: 1.0.0

;; Constants
(define-constant LIBRARY_CAPACITY u4000000)
(define-constant BASE_STUDY_REWARD u45)
(define-constant KNOWLEDGE_BONUS u25)
(define-constant MAX_SCHOLAR_LEVEL u30)
(define-constant ERR_INVALID_STUDY_ACTIVITY u1)
(define-constant ERR_NO_STUDY_TOKENS u2)
(define-constant ERR_LIBRARY_CAPACITY_EXCEEDED u3)
(define-constant BLOCKS_PER_ACADEMIC_TERM u3024)
(define-constant RESEARCH_MULTIPLIER u15)
(define-constant MIN_RESEARCH_PERIOD u1512)
(define-constant PROCRASTINATION_PENALTY u40)

;; Data Variables
(define-data-var total-study-tokens-distributed uint u0)
(define-data-var total-study-activities uint u0)
(define-data-var library-curator principal tx-sender)

;; Data Maps
(define-map scholar-activities principal uint)
(define-map scholar-study-tokens principal uint)
(define-map study-session-start-time principal uint)
(define-map scholar-knowledge-level principal uint)
(define-map scholar-last-activity principal uint)
(define-map scholar-research-project principal uint)
(define-map scholar-research-start-block principal uint)
(define-map subject-complexity principal uint)
(define-map scholar-publication-count principal uint)
(define-map academic-specialization principal uint)

;; Public Functions
(define-public (start-study-session (subject-area uint) (difficulty-level uint))
  (let
    (
      (scholar tx-sender)
    )
    (asserts! (and (> subject-area u0) (> difficulty-level u0) (<= difficulty-level u12)) (err ERR_INVALID_STUDY_ACTIVITY))
    (map-set study-session-start-time scholar burn-block-height)
    (map-set subject-complexity scholar difficulty-level)
    (ok true)
  ))

(define-public (complete-study-session (subject-area uint) (comprehension-score uint))
  (let
    (
      (scholar tx-sender)
      (start-block (default-to u0 (map-get? study-session-start-time scholar)))
      (blocks-studying (- burn-block-height start-block))
      (last-activity-block (default-to u0 (map-get? scholar-last-activity scholar)))
      (knowledge-level (default-to u0 (map-get? scholar-knowledge-level scholar)))
      (capped-knowledge (if (<= knowledge-level MAX_SCHOLAR_LEVEL) knowledge-level MAX_SCHOLAR_LEVEL))
      (comprehension-bonus (/ (* comprehension-score u15) u100))
      (specialization-bonus (default-to u0 (map-get? academic-specialization scholar)))
      (study-reward (+ BASE_STUDY_REWARD (* capped-knowledge KNOWLEDGE_BONUS) comprehension-bonus specialization-bonus))
    )
    (asserts! (and (> start-block u0) (>= blocks-studying subject-area) (<= comprehension-score u100)) (err ERR_INVALID_STUDY_ACTIVITY))
    
    (map-set scholar-activities scholar (+ (default-to u0 (map-get? scholar-activities scholar)) u1))
    (map-set scholar-study-tokens scholar (+ (default-to u0 (map-get? scholar-study-tokens scholar)) study-reward))
    
    (if (< (- burn-block-height last-activity-block) BLOCKS_PER_ACADEMIC_TERM)
      (map-set scholar-knowledge-level scholar (+ knowledge-level u1))
      (map-set scholar-knowledge-level scholar u1)
    )
    
    (if (>= comprehension-score u90)
      (map-set academic-specialization scholar (+ specialization-bonus u10))
      true
    )
    
    (map-set scholar-last-activity scholar burn-block-height)
    (var-set total-study-activities (+ (var-get total-study-activities) u1))
    (var-set total-study-tokens-distributed (+ (var-get total-study-tokens-distributed) study-reward))
    
    (asserts! (<= (var-get total-study-tokens-distributed) LIBRARY_CAPACITY) (err ERR_LIBRARY_CAPACITY_EXCEEDED))
    (ok study-reward)
  ))

(define-public (claim-study-rewards)
  (let
    (
      (scholar tx-sender)
      (token-balance (default-to u0 (map-get? scholar-study-tokens scholar)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_STUDY_TOKENS))
    (map-set scholar-study-tokens scholar u0)
    (ok token-balance)
  ))

;; Research Features
(define-public (start-research-project (project-scope uint))
  (let
    (
      (scholar tx-sender)
    )
    (asserts! (> project-scope u0) (err ERR_INVALID_STUDY_ACTIVITY))
    (asserts! (>= (var-get total-study-tokens-distributed) project-scope) (err ERR_LIBRARY_CAPACITY_EXCEEDED))
    
    (map-set scholar-research-project scholar project-scope)
    (map-set scholar-research-start-block scholar burn-block-height)
    (var-set total-study-tokens-distributed (- (var-get total-study-tokens-distributed) project-scope))
    (ok project-scope)
  ))

(define-public (complete-research-project)
  (let
    (
      (scholar tx-sender)
      (research-amount (default-to u0 (map-get? scholar-research-project scholar)))
      (research-start-block (default-to u0 (map-get? scholar-research-start-block scholar)))
      (blocks-researching (- burn-block-height research-start-block))
      (penalty (if (< blocks-researching MIN_RESEARCH_PERIOD) (/ (* research-amount PROCRASTINATION_PENALTY) u100) u0))
      (research-bonus (if (>= blocks-researching MIN_RESEARCH_PERIOD) (/ (* research-amount RESEARCH_MULTIPLIER) u100) u0))
      (final-amount (+ (- research-amount penalty) research-bonus))
    )
    (asserts! (> research-amount u0) (err ERR_NO_STUDY_TOKENS))
    
    (map-set scholar-research-project scholar u0)
    (map-set scholar-research-start-block scholar u0)
    (map-set scholar-publication-count scholar (+ (default-to u0 (map-get? scholar-publication-count scholar)) u1))
    (var-set total-study-tokens-distributed (+ (var-get total-study-tokens-distributed) final-amount))
    (ok final-amount)
  ))

(define-public (publish-academic-paper (research-quality uint) (peer-review-score uint))
  (let
    (
      (scholar tx-sender)
      (knowledge-level (default-to u0 (map-get? scholar-knowledge-level scholar)))
      (publication-count (default-to u0 (map-get? scholar-publication-count scholar)))
      (publication-bonus (+ (* research-quality u20) (* peer-review-score u18) (* publication-count u12)))
    )
    (asserts! (and (> research-quality u0) (> peer-review-score u0) (>= knowledge-level u12)) (err ERR_INVALID_STUDY_ACTIVITY))
    
    (map-set scholar-study-tokens scholar (+ (default-to u0 (map-get? scholar-study-tokens scholar)) publication-bonus))
    (var-set total-study-tokens-distributed (+ (var-get total-study-tokens-distributed) publication-bonus))
    
    (ok publication-bonus)
  ))

(define-public (mentor-junior-scholars (mentee-count uint) (mentoring-hours uint))
  (let
    (
      (scholar tx-sender)
      (knowledge-level (default-to u0 (map-get? scholar-knowledge-level scholar)))
      (specialization-level (default-to u0 (map-get? academic-specialization scholar)))
      (mentoring-bonus (+ (* mentee-count u35) (* mentoring-hours u8) (* specialization-level u5)))
    )
    (asserts! (and (> mentee-count u0) (> mentoring-hours u0) (>= knowledge-level u15)) (err ERR_INVALID_STUDY_ACTIVITY))
    
    (map-set scholar-study-tokens scholar (+ (default-to u0 (map-get? scholar-study-tokens scholar)) mentoring-bonus))
    (var-set total-study-tokens-distributed (+ (var-get total-study-tokens-distributed) mentoring-bonus))
    
    (ok mentoring-bonus)
  ))

;; Read-Only Functions
(define-read-only (get-study-activity-count (user principal))
  (default-to u0 (map-get? scholar-activities user)))

(define-read-only (get-study-token-balance (user principal))
  (default-to u0 (map-get? scholar-study-tokens user)))

(define-read-only (get-knowledge-level (user principal))
  (default-to u0 (map-get? scholar-knowledge-level user)))

(define-read-only (get-publication-count (user principal))
  (default-to u0 (map-get? scholar-publication-count user)))

(define-read-only (get-research-project (user principal))
  (default-to u0 (map-get? scholar-research-project user)))

(define-read-only (get-academic-specialization (user principal))
  (default-to u0 (map-get? academic-specialization user)))

(define-read-only (get-library-stats)
  {
    total-study-activities: (var-get total-study-activities),
    total-study-tokens-distributed: (var-get total-study-tokens-distributed),
    library-capacity: LIBRARY_CAPACITY
  })

(define-read-only (calculate-study-reward (knowledge-level uint) (comprehension-score uint) (specialization-bonus uint))
  (let
    (
      (capped-knowledge (if (<= knowledge-level MAX_SCHOLAR_LEVEL) knowledge-level MAX_SCHOLAR_LEVEL))
      (comprehension-bonus (/ (* comprehension-score u15) u100))
    )
    (+ BASE_STUDY_REWARD (* capped-knowledge KNOWLEDGE_BONUS) comprehension-bonus specialization-bonus)
  ))

;; Private Functions
(define-private (is-library-curator)
  (is-eq tx-sender (var-get library-curator)))

(define-private (validate-study-parameters (subject-area uint) (comprehension-score uint))
  (and (> subject-area u0) (<= comprehension-score u100)))