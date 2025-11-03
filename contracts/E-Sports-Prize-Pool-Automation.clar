(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TOURNAMENT-NOT-FOUND (err u101))
(define-constant ERR-TOURNAMENT-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PRIZE-AMOUNT (err u103))
(define-constant ERR-TOURNAMENT-NOT-ACTIVE (err u104))
(define-constant ERR-ALREADY-REGISTERED (err u105))
(define-constant ERR-NOT-REGISTERED (err u106))
(define-constant ERR-REGISTRATION-CLOSED (err u107))
(define-constant ERR-INSUFFICIENT-BALANCE (err u108))
(define-constant ERR-TOURNAMENT-ALREADY-COMPLETED (err u109))
(define-constant ERR-INVALID-WINNER-COUNT (err u110))
(define-constant ERR-PRIZE-ALREADY-CLAIMED (err u111))
(define-constant ERR-INVALID-SPONSORSHIP-AMOUNT (err u112))

(define-constant TOURNAMENT-STATUS-CREATED u0)
(define-constant TOURNAMENT-STATUS-ACTIVE u1)
(define-constant TOURNAMENT-STATUS-COMPLETED u2)

(define-data-var next-tournament-id uint u1)

(define-map tournaments uint {
    name: (string-ascii 50),
    organizer: principal,
    prize-pool: uint,
    max-participants: uint,
    registration-end: uint,
    tournament-end: uint,
    status: uint,
    participant-count: uint,
    entry-fee: uint
})

(define-map participants {tournament-id: uint, participant: principal} {
    registered-at: uint,
    prize-claimed: bool
})

(define-map tournament-winners uint {
    first-place: (optional principal),
    second-place: (optional principal),
    third-place: (optional principal),
    prize-distributed: bool
})

(define-map prize-distribution uint {
    first-place-percent: uint,
    second-place-percent: uint,
    third-place-percent: uint
})

(define-map tournament-sponsors {tournament-id: uint, sponsor: principal} {
    amount: uint,
    sponsored-at: uint
})

(define-map tournament-total-sponsorship uint uint)

(define-public (create-tournament 
    (name (string-ascii 50))
    (max-participants uint)
    (registration-blocks uint)
    (tournament-blocks uint)
    (entry-fee uint)
    (first-percent uint)
    (second-percent uint)
    (third-percent uint))
    (let ((tournament-id (var-get next-tournament-id))
          (current-height stacks-block-height)
          (registration-end (+ current-height registration-blocks))
          (tournament-end (+ registration-end tournament-blocks)))
        (asserts! (and (> max-participants u2) (<= max-participants u100)) ERR-INVALID-PRIZE-AMOUNT)
        (asserts! (and (> registration-blocks u0) (> tournament-blocks u0)) ERR-INVALID-PRIZE-AMOUNT)
        (asserts! (is-eq (+ first-percent second-percent third-percent) u100) ERR-INVALID-PRIZE-AMOUNT)
        (try! (stx-transfer? entry-fee tx-sender (as-contract tx-sender)))
        (map-set tournaments tournament-id {
            name: name,
            organizer: tx-sender,
            prize-pool: entry-fee,
            max-participants: max-participants,
            registration-end: registration-end,
            tournament-end: tournament-end,
            status: TOURNAMENT-STATUS-CREATED,
            participant-count: u0,
            entry-fee: entry-fee
        })
        (map-set prize-distribution tournament-id {
            first-place-percent: first-percent,
            second-place-percent: second-percent,
            third-place-percent: third-percent
        })
        (var-set next-tournament-id (+ tournament-id u1))
        (ok tournament-id)))

(define-public (register-for-tournament (tournament-id uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR-TOURNAMENT-NOT-FOUND))
          (current-height stacks-block-height))
        (asserts! (< current-height (get registration-end tournament)) ERR-REGISTRATION-CLOSED)
        (asserts! (< (get participant-count tournament) (get max-participants tournament)) ERR-REGISTRATION-CLOSED)
        (asserts! (is-none (map-get? participants {tournament-id: tournament-id, participant: tx-sender})) ERR-ALREADY-REGISTERED)
        (try! (stx-transfer? (get entry-fee tournament) tx-sender (as-contract tx-sender)))
        (map-set participants {tournament-id: tournament-id, participant: tx-sender} {
            registered-at: current-height,
            prize-claimed: false
        })
        (map-set tournaments tournament-id 
            (merge tournament {
                participant-count: (+ (get participant-count tournament) u1),
                prize-pool: (+ (get prize-pool tournament) (get entry-fee tournament))
            }))
        (ok true)))

(define-public (start-tournament (tournament-id uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR-TOURNAMENT-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get organizer tournament)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status tournament) TOURNAMENT-STATUS-CREATED) ERR-TOURNAMENT-NOT-ACTIVE)
        (asserts! (>= (get participant-count tournament) u3) ERR-INVALID-PRIZE-AMOUNT)
        (map-set tournaments tournament-id 
            (merge tournament {status: TOURNAMENT-STATUS-ACTIVE}))
        (ok true)))

(define-public (complete-tournament 
    (tournament-id uint)
    (first-place principal)
    (second-place principal)
    (third-place principal))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR-TOURNAMENT-NOT-FOUND))
          (current-height stacks-block-height))
        (asserts! (is-eq tx-sender (get organizer tournament)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status tournament) TOURNAMENT-STATUS-ACTIVE) ERR-TOURNAMENT-NOT-ACTIVE)
        (asserts! (>= current-height (get tournament-end tournament)) ERR-TOURNAMENT-NOT-ACTIVE)
        (asserts! (is-some (map-get? participants {tournament-id: tournament-id, participant: first-place})) ERR-NOT-REGISTERED)
        (asserts! (is-some (map-get? participants {tournament-id: tournament-id, participant: second-place})) ERR-NOT-REGISTERED)
        (asserts! (is-some (map-get? participants {tournament-id: tournament-id, participant: third-place})) ERR-NOT-REGISTERED)
        (asserts! (and (not (is-eq first-place second-place)) 
                      (not (is-eq first-place third-place)) 
                      (not (is-eq second-place third-place))) ERR-INVALID-WINNER-COUNT)
        (map-set tournament-winners tournament-id {
            first-place: (some first-place),
            second-place: (some second-place),
            third-place: (some third-place),
            prize-distributed: false
        })
        (map-set tournaments tournament-id 
            (merge tournament {status: TOURNAMENT-STATUS-COMPLETED}))
        (ok true)))

(define-public (claim-prize (tournament-id uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR-TOURNAMENT-NOT-FOUND))
          (participant-data (unwrap! (map-get? participants {tournament-id: tournament-id, participant: tx-sender}) ERR-NOT-REGISTERED))
          (winners (unwrap! (map-get? tournament-winners tournament-id) ERR-TOURNAMENT-NOT-ACTIVE))
          (distribution (unwrap! (map-get? prize-distribution tournament-id) ERR-TOURNAMENT-NOT-FOUND)))
        (asserts! (is-eq (get status tournament) TOURNAMENT-STATUS-COMPLETED) ERR-TOURNAMENT-NOT-ACTIVE)
        (asserts! (not (get prize-claimed participant-data)) ERR-PRIZE-ALREADY-CLAIMED)
        (let ((prize-amount 
                (if (is-eq (some tx-sender) (get first-place winners))
                    (/ (* (get prize-pool tournament) (get first-place-percent distribution)) u100)
                    (if (is-eq (some tx-sender) (get second-place winners))
                        (/ (* (get prize-pool tournament) (get second-place-percent distribution)) u100)
                        (if (is-eq (some tx-sender) (get third-place winners))
                            (/ (* (get prize-pool tournament) (get third-place-percent distribution)) u100)
                            u0)))))
            (asserts! (> prize-amount u0) ERR-NOT-AUTHORIZED)
            (try! (as-contract (stx-transfer? prize-amount tx-sender tx-sender)))
            (map-set participants {tournament-id: tournament-id, participant: tx-sender}
                (merge participant-data {prize-claimed: true}))
            (ok prize-amount))))

(define-public (emergency-refund (tournament-id uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR-TOURNAMENT-NOT-FOUND))
          (participant-data (unwrap! (map-get? participants {tournament-id: tournament-id, participant: tx-sender}) ERR-NOT-REGISTERED))
          (current-height stacks-block-height))
        (asserts! (> current-height (+ (get tournament-end tournament) u1440)) ERR-TOURNAMENT-NOT-ACTIVE)
        (asserts! (is-eq (get status tournament) TOURNAMENT-STATUS-ACTIVE) ERR-TOURNAMENT-ALREADY-COMPLETED)
        (asserts! (not (get prize-claimed participant-data)) ERR-PRIZE-ALREADY-CLAIMED)
        (try! (as-contract (stx-transfer? (get entry-fee tournament) tx-sender tx-sender)))
        (map-set participants {tournament-id: tournament-id, participant: tx-sender}
            (merge participant-data {prize-claimed: true}))
        (ok (get entry-fee tournament))))

(define-read-only (get-tournament (tournament-id uint))
    (map-get? tournaments tournament-id))

(define-read-only (get-tournament-winners (tournament-id uint))
    (map-get? tournament-winners tournament-id))

(define-read-only (get-prize-distribution (tournament-id uint))
    (map-get? prize-distribution tournament-id))

(define-read-only (is-participant (tournament-id uint) (participant principal))
    (is-some (map-get? participants {tournament-id: tournament-id, participant: participant})))

(define-read-only (get-participant-data (tournament-id uint) (participant principal))
    (map-get? participants {tournament-id: tournament-id, participant: participant}))

(define-read-only (get-next-tournament-id)
    (var-get next-tournament-id))

(define-read-only (calculate-prize (tournament-id uint) (place uint))
    (match (map-get? tournaments tournament-id)
        tournament (match (map-get? prize-distribution tournament-id)
            distribution 
                (if (is-eq place u1)
                    (ok (/ (* (get prize-pool tournament) (get first-place-percent distribution)) u100))
                    (if (is-eq place u2)
                        (ok (/ (* (get prize-pool tournament) (get second-place-percent distribution)) u100))
                        (if (is-eq place u3)
                            (ok (/ (* (get prize-pool tournament) (get third-place-percent distribution)) u100))
                            ERR-INVALID-WINNER-COUNT)))
            ERR-TOURNAMENT-NOT-FOUND)
        ERR-TOURNAMENT-NOT-FOUND))

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender)))

(define-read-only (can-register (tournament-id uint))
    (match (map-get? tournaments tournament-id)
        tournament
            (and 
                (< stacks-block-height (get registration-end tournament))
                (< (get participant-count tournament) (get max-participants tournament))
                (is-eq (get status tournament) TOURNAMENT-STATUS-CREATED))
        false))

(define-read-only (tournament-info (tournament-id uint))
    (match (map-get? tournaments tournament-id)
        tournament
            (ok {
                tournament: tournament,
                winners: (map-get? tournament-winners tournament-id),
                distribution: (map-get? prize-distribution tournament-id),
                can-register: (can-register tournament-id),
                blocks-until-registration-end: (if (> (get registration-end tournament) stacks-block-height)
                                                  (- (get registration-end tournament) stacks-block-height)
                                                  u0),
                blocks-until-tournament-end: (if (> (get tournament-end tournament) stacks-block-height)
                                                (- (get tournament-end tournament) stacks-block-height)
                                                u0)
            })
        ERR-TOURNAMENT-NOT-FOUND))

(define-public (sponsor-tournament (tournament-id uint) (amount uint))
    (let ((tournament (unwrap! (map-get? tournaments tournament-id) ERR-TOURNAMENT-NOT-FOUND))
          (current-height stacks-block-height)
          (current-sponsorship (default-to u0 (map-get? tournament-total-sponsorship tournament-id)))
          (existing-sponsor (map-get? tournament-sponsors {tournament-id: tournament-id, sponsor: tx-sender}))
          (existing-amount (match existing-sponsor sponsor-data (get amount sponsor-data) u0))
          (new-total-amount (+ amount existing-amount)))
        (asserts! (> amount u0) ERR-INVALID-SPONSORSHIP-AMOUNT)
        (asserts! (< (get status tournament) TOURNAMENT-STATUS-COMPLETED) ERR-TOURNAMENT-ALREADY-COMPLETED)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set tournament-sponsors {tournament-id: tournament-id, sponsor: tx-sender} {
            amount: new-total-amount,
            sponsored-at: current-height
        })
        (map-set tournament-total-sponsorship tournament-id (+ current-sponsorship amount))
        (map-set tournaments tournament-id 
            (merge tournament {prize-pool: (+ (get prize-pool tournament) amount)}))
        (ok amount)))

(define-read-only (get-tournament-sponsorship (tournament-id uint))
    (default-to u0 (map-get? tournament-total-sponsorship tournament-id)))

(define-read-only (get-sponsor-contribution (tournament-id uint) (sponsor principal))
    (map-get? tournament-sponsors {tournament-id: tournament-id, sponsor: sponsor}))
