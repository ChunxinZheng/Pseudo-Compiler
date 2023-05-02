#lang racket

;; AUTHORS: Lex Stapleton, Chunxin Zheng

;;    Basic Information 
;; ---------------------------------------------------------------------

;; This is an assembler that converts a pseudocode PRIMPL to its assembler language A-PRIMPL.
;; Both languages were designed by the University of Waterloo CS 146 instructor team.
;; More detailed information, including the grammar for both languages, is included in README.
;; The PRIMPL Simulator (Simulator.rkt) was provided by the University of Waterloo
;; CS 146 instructor team.



;;    User Guide
;; ---------------------------------------------------------------------

(require "Simulator.rkt")

(define (run primpl) (load-primp primpl) (run-primp))

;; [primpl-assemble] produces a list of the converted PRIMPL code corresponding to
;; the consumed A-PRIMPL code.
;; The PRIMPL code can be executed by the provided PRIMPL Simulator.

;; Run the function (primpl-assemble aprimpl), where [aprimpl] is a list of APRIMPL instructions,
;;     to see the converted PRIMPL code.
;; Run the function (run primpl), where [primpl] is a list of PRIMPL instructions
;;     to see the result of running the program.


;;    Example
;; ---------------------------------------------------------------------

;; The following A-PRIMPL code produces the factorial of 5 (120).

;;'((label TOP)
;;  (equal cond x 0)
;;  (branch cond DONE)
;;  (mul y y x)
;;  (sub x x 1)
;;  (jump TOP)
;;  (label DONE)
;;  (print-val y)
;;  (halt)
;;  (data x 5)
;;  (data y 1)
;;  (data cond #t))

;; The converted PRIMPL code is

;;'((equal (9) (7) 0)
;;  (branch (9) 5)
;;  (mul (8) (8) (7))
;;  (sub (7) (7) 1)
;;  (jump 0)
;;  (print-val (8))
;;  0
;;  5
;;  1
;;  #t)

;; The value can be varified by
;; (run ...[insert the PRIMPL code here])



;;    Assemble (Main Function) 
;; ---------------------------------------------------------------------

(define (primpl-assemble aprimpl)
  (define scanned (first-scan aprimpl empty 0 empty))
  (define prog-with-psymbols (result-prog scanned))
  (define psymbol-list (result-table scanned))
  (define psymbol-table (generate-psymbol-table psymbol-list))
  (translate prog-with-psymbols psymbol-table empty))


;;    Error Handling
;; ---------------------------------------------------------------------

(define ((base-error msg) extra) (error (format "~a: ~a" msg extra)))

(define circular-reference-error  (base-error "circular reference error"))
(define undefined-reference-error (base-error "undefined symbol"))
(define duplicate-reference-error (base-error "duplicate symbol"))
(define incorrect-usage-error (base-error "incorrect symbol usage"))


;;    Basic Types of Special Pseudo-instructions
;; ---------------------------------------------------------------------

(struct psymbol (type name val) #:transparent)
(define (make-label name loc) (psymbol 'label name loc))
(define (make-const name val) (psymbol 'const name val))
(define (make-data  name loc) (psymbol 'data  name loc))


;;    First Scan
;; ---------------------------------------------------------------------

(struct result (prog table)  #:transparent #:mutable)

;; An instruction (Ins) is (listof Sym)

;; first-scan: (listof Ins) (listof Ins) Int (listof psymbol) -> result

;; [first-scan] scans through the given code for the first time,
;; collect special pseudo-instructions ([label], [const], and [data]) to a table,
;; and modified the given code

;; (first-scan aprimpl empty 0 empty), produced new code is reversed
(define (first-scan lst acc count table)
  (cond [(empty? lst) (result acc table)]
        [else
         (match (first lst)
           [`(halt) (first-scan (rest lst) (cons 0 acc) (+ 1 count) table)]
           [`(const ,psymbol ,val)
            (first-scan (rest lst) acc count (cons (make-const psymbol val) table))]
           [`(label ,psymbol)
            (first-scan (rest lst) acc count (cons (make-label psymbol count) table))]
           [`(data ,psymbol (,nat ,val))
            (first-scan (rest lst) (cons (first lst) acc)
                        (+ nat count) (cons (make-data psymbol count) table))]
           [`(data ,psymbol ...)
            (first-scan (rest lst)
                        (cons (first lst) acc)
                        (+ (- (length (first lst)) 2) count)
                        (cons (make-data (first psymbol) count) table))]
           [`(jsr ,dest ,pc)
            (first-scan (rest lst)
                        (cons (list 'move dest count) (cons (list 'jump pc) acc))
                        (+ count 1) table)]
           [else (first-scan (rest lst) (cons (first lst) acc) (+ 1 count) table)])]))



;;    Generate Symbol Table
;; ---------------------------------------------------------------------

(define (make-psymbol-hash-table psymbols)
  (define (h psymbols table)
    (define (name) (psymbol-name (car psymbols)))
    ;; make name a thunk to stop it from evaluating when psymbols is empty
    (cond
      [(empty? psymbols) table]
      [(not (hash-ref-key table (name) #f))
       (h (cdr psymbols) (hash-set table (name) (car psymbols)))]
      [else (duplicate-reference-error (format "found duplicate symbol ~a" name))]))
  (h psymbols (make-immutable-hash)))

(define (generate-psymbol-table psymbols)
  (define (h sym-table env cur stack defs is_base)
    (cond
      [(not (eq? 'undef cur))
       (define type (psymbol-type cur))
       (define name (psymbol-name cur))
       (define val  (psymbol-val  cur))
       (if (lit? val)
           (h (hash-set sym-table name (psymbol type name val)) env 'undef stack defs is_base)
           (let
               ([stored-val (hash-ref sym-table val #f)]
                [traced-val (hash-ref env       val #f)])
             (cond
               [stored-val (h (hash-set sym-table name (psymbol type name (psymbol-val stored-val)))
                              env 'undef stack defs #t)]
               [traced-val
                (define traced-env (hash-remove env name))
                (h sym-table traced-env traced-val (cons (list env cur) stack) defs #f)]
               [else
                (if is_base
                    (undefined-reference-error val)
                    (circular-reference-error val))]
               )))]
      [(not (empty? stack )) (h sym-table (first (first stack))
                                (second (first stack)) (cdr stack) defs #t)]
      [(not (empty? defs  )) (h sym-table env (first defs) stack (rest defs) #t)]
      [else sym-table]
      ))
  (h (make-immutable-hash)
     (make-psymbol-hash-table psymbols)
     'undef
     empty
     psymbols
     #t))
  

;;    Resolving Parameters 
;; ---------------------------------------------------------------------


;; ----- Type Checking Helpers -----

(define (lit? l) (or (number? l) (boolean? l)))

(define (label? l) (and (psymbol? l) (symbol=? 'label (psymbol-type l))))
(define (data? l)  (and (psymbol? l) (symbol=? 'data  (psymbol-type l))))
(define (const? l) (and (psymbol? l) (symbol=? 'const (psymbol-type l))))

;; ----- Looking Up -----
(define (lookup-entry table symbol)
  (hash-ref table symbol #f))


;; ----- Resolving the First Opd in an Offset -----

(define (resolve-index-first table symbol)
  (cond
    [(symbol? symbol)
     (define psym (lookup-entry table symbol))
     (unless psym (undefined-reference-error (format "psymbol ~a is undefined" symbol)))
     (define val (psymbol-val psym))
     (cond
       [(const? psym) val]
       [(data?  psym) val]
       [else (incorrect-usage-error
              (format "cannot use ~a as the first value of an indexed access" symbol))])]
    [(lit? symbol) symbol]
    [else symbol]))


;; ----- Resolving the Second Opd in an Offset -----

(define (resolve-index-second table symbol)
  (cond
    [(symbol? symbol)
     (define psym (lookup-entry table symbol))
     (unless psym (undefined-reference-error (format "psymbol ~a is undefined" symbol)))
     (define val (psymbol-val psym))
     (cond 
       [(const? psym) (list val)]
       [(data?  psym) (list val)]
       [else (incorrect-usage-error
              (format "cannot use ~a as the second value of an indexed access" symbol))])]
    [(list? symbol) symbol]
    [else symbol]))


;; ----- Resolving [lit], [data] or [const] -----

(define (resolve-lit-data-const table symbol)
  (cond
    [(symbol? symbol)
     (define psym (lookup-entry table symbol))
     (if psym
         (psymbol-val psym)
         (undefined-reference-error (format "psymbol ~a is undefined" symbol)))]
    [(lit? symbol) symbol]
    [else symbol]))


;; ----- Resolving [jump] or [branch] -----

(define (resolve-jump-branch table symbol)
  (cond
    [(symbol? symbol)
     (define psym (lookup-entry table symbol))
     (unless psym (undefined-reference-error (format "psymbol ~a is undefined" symbol)))
     (define val (psymbol-val psym))
     (cond 
       [(const? psym)       val ]
       [(data?  psym) (list val)]
       [(label? psym)       val ]
       [else (incorrect-usage-error
              (format "cannot use ~a as a the destination of a jump/branchs" symbol))])]
    [(lit? symbol) symbol]
    [else symbol]))


;; ----- Resolving the Opd in Remaining Instructions -----

(define (resolve-opd table symbol)
  (match symbol

    [`(,fst ,snd)
     (list (resolve-index-first  table fst)
           (resolve-index-second table snd))]
    [(? symbol? symbol)
     (define psym (lookup-entry table symbol))
     (unless psym (undefined-reference-error (format "psymbol ~a is undefined" symbol)))
     (define val (psymbol-val psym))
     (cond
       [(const? psym)       val ]
       [(data?  psym) (list val)]
       [else (incorrect-usage-error (format "cannot use ~a as an opd" symbol))])]
    [x symbol]))


;; ----- Resolving the Dest in Remaining Instructions -----

(define (resolve-dest table symbol)
  (match symbol
    [`(,fst ,snd)
     (list (resolve-index-first  table fst)
           (resolve-index-second table snd))]
    [(? symbol? symbol)
     (define psym (lookup-entry table symbol))
     (unless psym (undefined-reference-error (format "psymbol ~a is undefined" symbol)))
     (define val (psymbol-val psym))
     (cond
       [(data? psym) (list val)]
       [else (incorrect-usage-error (format "cannot use ~a as a dest" symbol))])]
    [x symbol]))

;;    Final Replacement
;; ---------------------------------------------------------------------

;; translate: (listof Ins) (listof psymbol) (listof Ins) -> (listof Ins)

; (translate prog table empty)
;; [prog] is reversed, [translate] reverses it back

(define (translate lst table acc)
  (cond [(empty? lst) acc]
        [else
         (match (first lst)
           [`(jump ,opd)
            (translate (rest lst) table (cons (list 'jump (resolve-jump-branch table opd)) acc))]
           [`(branch ,opd1 ,opd2)
            (translate (rest lst) table
                       (cons (list 'branch (resolve-opd table opd1)
                                   (resolve-jump-branch table opd2)) acc))]
           [`(lit ,v)
            (translate (rest lst) table (cons (resolve-lit-data-const table v) acc))] 
           [`(data ,psymbol (,nat ,val))
            (define v (resolve-lit-data-const table val))
            (translate (rest lst) table
                       (append (build-list nat (lambda (x) v)) acc))]
           [`(data ,psymbol ,vals ...)
            (translate (rest lst) table
                       (append (foldr (lambda (x l) (cons (resolve-lit-data-const table x) l))
                                      empty vals) acc))]
           [`(print-val ,opd) (translate (rest lst) table
                                         (cons (list 'print-val (resolve-opd table opd)) acc))]
           [`(print-string ,str) (translate (rest lst) table (cons (first lst) acc))]
           [`(,fun ,dest ,opds ...)
            (translate (rest lst) table
                       (cons (append (list fun (resolve-dest table dest))
                                     (map (lambda (opd) (resolve-opd table opd)) opds)) acc))]
           ['(halt) (translate (rest lst) table (cons 0 acc))]
           [else (translate (rest lst) table (cons (first lst) acc))])]))



