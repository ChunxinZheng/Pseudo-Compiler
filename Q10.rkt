#lang racket

;(require "Q8.rkt" "primpl.rkt")

;; AUTHORS: Lex Stapleton, Chunxin Zheng



;(require test-engine/racket-tests)

(define ((base-error msg) extra) (error (format "~a: ~a" msg extra)))

(define unknown-operator-error  (base-error "unknown operator error"))
(define unknown-function-error  (base-error "unknown function error"))
(define duplicate-function-error  (base-error "duplicate function error"))
(define duplicate-identifer-error  (base-error "duplicate identifer error"))
(define malformed-function-error  (base-error "malformed function error (may miss return)"))
(define unknown-identifer-error  (base-error "unknown function error"))
(define missing-return-error  (base-error "missing return error"))
(define arguments-error (base-error "incorrect number of arguments"))


(define inst (λ x (list x)))

(define (stack-size) '(256 9973))

;;    FUNCTION TABLE
;; -----------------------------------------
;;
;;  make-function-table prog
;;  get-number-args table name
;;

(struct function (id args locals environment body) #:transparent)

(define (make-hash-no-repeat lst err)
  (define (h p acc)
    (cond
      [(empty? p) acc]
      [(hash-ref-key acc (caar p) #f) (err (caar p))]
      [else (h (cdr p)
             (hash-set
              acc
              (first (first p))
              (second (first p))))]))
  (h lst (make-immutable-hash)))

(define (generate-environment vars)
  (define counter 0)
  (make-hash-no-repeat
   (map (λ(x)(set! counter (add1 counter)) `(,x (,(sub1 counter) fp))) vars)
   duplicate-identifer-error))

(define (generate-function-table prog)
  (define (h src)
    (match src
      [`(fun
         (,name ,args ...)
         ,(and body `(vars
                      ,(and locals `((,_ ,_) ...))
                      ,stmts ...
                      ,(and return `(return ,_)))))
;       (display name)
;        (display "----------!!!!!!!")
;        (display (length args));;;; not working
       (list name
             (function
              name
              (length args)
              (length locals)
              (generate-environment (append args (map first locals)))
              body))]
      [`(fun
         (,name)
         ,(and body `(vars
                      ,(and locals `((,_ ,_) ...))
                      ,stmts ...)))
       (missing-return-error src)]
      [x (malformed-function-error x)]))
  (make-hash-no-repeat (map h prog) duplicate-function-error))
;
;(define (get-number-args table name)
;  (define out (hash-ref table name #f))
;  (unless out (unknown-function-error (format "could not find function with id ~a" name)))
;  (function-args-count out))

(define (get-func table name)
  (define out (hash-ref table name #f))
  (unless out (unknown-function-error (format "could not find function with id ~a" name)))
  out)

;;    TESTS
;; -----------------------------------------

;(check-error (make-function-table '((fun () (return 0)))))
;(check-error (make-function-table '((fun (name1)))))
;(check-error (make-function-table '((fun () (return 0)))))
;(check-error (make-function-table '((func (name1) (return 0)))))
;
;
;(define prog '((fun (name1) (vars [] (return 0))) (fun (name2 arg1) (vars [(id 1)] (return 0)))))
;(define func-table (make-function-table prog))
;
;(check-expect (get-number-args func-table 'name1) 0)
;(check-expect (get-number-args func-table 'name2) 1)
;(check-expect (get-number-args func-table 'name3) 3)
;(check-error (get-number-args func-table 'not-a-name))
;(check-error (get-number-args func-table 5))


;;    FUNCTIONS APP/ RETURN
;; -----------------------------------------

(define (apply-function id pars env)

  (define func (get-func func-table id))
  (define num_args (function-args func))
  (define num_locals (function-locals func))
;  (display "---------------------")
;  (display num_args)
;  (newline)
;  (display pars)
;  (newline)
;  (display (length pars))
  
  (cond [(= (length pars) num_args)
            
         (append
             
          (inst 'move '(0 sp) 0)   ;; reserved for jsr/return_value
          (inst 'move '(1 sp) 'fp) ;; previous value of the frame pointer 

          (inst 'add 'sp 'sp 2)
          
          ;; eval parameters
          (foldr append empty (map (λ(x) (compile-exp x env)) pars))
             
          (inst 'sub 'fp  'sp num_args) ;; set the frame pointer to the first arg
        
          (inst 'jsr '(-2 fp) (string->symbol (format "_~a" id)))
          (inst 'move '(-2 fp) '(-1 sp))
             
          (inst 'sub 'sp 'fp 1) ;; set the frame pointer back such that the top of the stack is the result
             
          (inst 'move 'fp '(-1 fp)) ;; set the frame pointer to the first arg
      
          )]
           
        [else (arguments-error (format "mismatch for function ~a" id))]))


;;    OP TRANSLATION
;; -----------------------------------------
(define op-table (make-hash '((+ add) (- sub) (* mul) (div div) (mod mod)
                                      (< lt) (> gt) (<= le) (>= ge) (= equal) (!= not-equal)
                                      (and land) (or lor) (not lnot))))

(define (builtin? name)
  (not (not (hash-ref-key op-table name #f))))

(define (trans-op symbol)
  (define out (hash-ref op-table symbol #f))
  (if out (car out) (unknown-operator-error (format "could not find operator ~a" symbol))))

;;    EXPRESTION EVALUATION
;; ----------------------------------------

(define (imm? x) (or (symbol? x) (number? x) (boolean? x)))
(define (get-imm x env)
  (cond
    [(eq? 'true  x) #t]
    [(eq? 'false x) #f]
    [(symbol? x) (hash-ref env x x)]
    [else x]))

(define (compile-exp exp env)

  (match exp
    [(? imm? exp)
     (append
      (inst 'move '(0 sp) (get-imm exp env))
      (inst 'add  'sp 'sp 1))]
    [(list 'and ops ...) (compile-and exp env)]
    [(list 'or  ops ...) (compile-or  exp env)] 
    [(list 'seq stmts ... last)
     (append (compile-seq stmts)
             (compile-exp last))]
    [(list (? builtin? binop) subexp1 subexp2)
     (generate-binop-frame binop subexp1 subexp2 env)]
    [(list (? builtin? unop) subexp1)
     (generate-unop-frame unop subexp1 env)]
    [(list name args ...)
;     (newline)
;     (display "matched -----")
;     (display args)
;     (newline)
     (apply-function name args env)]))


(define (compile-and exp env)
  (match exp
    [(list 'and ops ...)
     (cond
       [(empty? ops)
        (append
         (inst 'move 'sp #t)
         (inst 'add  'sp 'sp 1))]
       
       [(empty? (rest ops))
        (compile-exp (first ops) env)]
       
       [(empty? (rest (rest ops)))
        (generate-binop-frame 'and (first ops) (second ops) env)]
       
       [else
        (generate-binop-frame 'and (first ops) (cons 'and (rest ops)) env)])]))

(define (compile-or exp env)
  (match exp
    [(list 'or ops ...)
     (cond
       [(empty? ops)
        (append
         (inst 'move 'sp #f)
         (inst 'add  'sp 'sp 1))]
       [(empty? (rest ops))
        (compile-exp (first ops) env)]
       [(empty? (rest (rest ops)))
        (generate-binop-frame 'or (first ops) (second ops) env)]
       [else
        (generate-binop-frame 'or (first ops) (cons 'or (rest ops)) env)])]))


(define (generate-binop-frame op exp1 exp2 env)
  (define val1 (compile-exp exp1 env))
  (define val2 (compile-exp exp2 env))
  (define binop (trans-op op))
  (append
    val1
    val2
   (inst 'sub 'sp 'sp 1)
   (inst binop '(-1 sp) '(-1 sp) '(0 sp))))

(define (generate-unop-frame op exp1 env)
  (define val1 (compile-exp exp1 env))
  (define unop (trans-op op))
  (append
    val1
   (inst unop '(-1 sp) '(-1 sp))))



;;    STATEMENT COMPILATION
;; ----------------------------------------


;(define compile-exp +)

(define counter
  (let [(c 0)]
    (λ()(set! c (+ c 1)) c)))

(define (compile-return exp env)
  (append
   (compile-exp exp env)
   (inst 'jump '(-2 fp))))

;;;; fix
(define (compile-set var exp env)
  (define target (hash-ref env var #f))
  (unless target  (unknown-identifer-error var))
  (append
   (compile-exp exp env)
   (inst 'move target '(-1 sp))))


(define (compile-iif test texp fexp env)
  ;; labels
  (define c (counter))
  (define jump_true (string->symbol (format "IF_TRUE_~a" c)))
  (define jump_end (string->symbol (format "IF_END_~a" c)))

  (define c_test (compile-exp test env))
  (define c_texp (compile-stmt texp env))
  (define c_fexp (compile-stmt fexp env))
  (append
        c_test
        (inst 'sub 'sp 'sp 1)
        (inst 'branch '(0 sp) jump_true)
        c_fexp
        (inst 'jump jump_end)
        (inst 'label jump_true)
        c_texp
        (inst 'label jump_end)))

(define (compile-seq stmts env)
  (foldr append empty  (map (lambda (x) (compile-stmt x env)) stmts)))

(define (compile-while test stmts env)
  ;; labels
  (define c (counter))
  (define while_top (string->symbol (format "WHILE_TOP_~a" c)))
  (define while_body (string->symbol (format "WHILE_BODY_~a" c)))
  (define while_end (string->symbol (format "WHILE_END_~a" c)))
  ;; pre compute if possible
  (define expr (compile-exp test env))
  (append 
        (inst 'label while_top)
        expr
        (inst 'sub 'sp 'sp 1)
        (inst 'branch '(0 sp) while_body)
        (inst 'jump while_end)
        (inst 'label while_body)
        (compile-seq stmts env)
        (inst 'jump while_top)
        (inst 'label while_end)))

(define (compile-print expr env)
  (cond
    [(string? expr) (inst 'print-string expr)]
    [else (append 
           (compile-exp expr env)
           (inst 'sub 'sp 'sp 1)
           (inst 'print-val '(0 sp)))]))
  
(define (compile-stmt stmt env)

  (match stmt
    [`(set ,var ,expr) (compile-set var expr env)]
    [`(iif ,test ,tstmt ,fstms) (compile-iif  test tstmt fstms env)]
    [`(seq ,stmts ...) (compile-seq stmts env)]
    [`(while ,test ,stmts ...) (compile-while test stmts env)]
    [`(print ,expr) (compile-print expr env)]
    [`(return ,val) (compile-return val env)]
    [`(skip) empty]
    [x (compile-exp x env)]))

;;    COMPILE FUNCTIONS BODIES
;; -----------------------------------------

(define (compile-locals locals environment)
  (define (f local)
    (define dest (hash-ref environment (first local) #f))
    (unless dest (error (format "could not find local ~a" local)))
    (inst 'move dest (second local)))
  (append
   (foldr append empty (map f locals))
   (inst 'add 'sp 'sp (length locals))))


;; func is struct function
(define (compile-func f)
  (match f [`(fun
              (,id ,args ...)
              ,(and body `(vars
                           ,(and locals `((,_ ,_) ...))
                           ,stmts ...
                           ,(and return `(return ,_)))))
            (define func (get-func func-table id))
            (define env  (function-environment func))

            (append
             (inst 'label (string->symbol (format "_~a" id)))
             (compile-locals locals env)
             (compile-seq stmts env)
             (compile-stmt return env))]
    [else (malformed-function-error f)]))

;;     COMPILE PROGRAM
;; -------------------------------
(define (compile-simpl prog)
  (set! func-table (generate-function-table prog))
  (define res (hash-ref func-table 'main #f))
  (cond [(boolean? res) empty]
        [else
         (append
          (inst 'jump '_MAIN)
          (foldr append empty (map compile-func prog))
          (inst 'label '_MAIN)
          (apply-function 'main empty (make-hash))
          (inst 'halt)
          (inst 'data 'sp 'stack)
          (inst 'data 'fp 'stack)
          (inst 'data 'stack (stack-size)))]
        ))

(define func-table empty)



;(define prog1 '((fun (f a b)(vars[](return (+ (* a a) b))))(fun (main)(vars () (print (f 3 2)) (print "here") (return 0)))))
;;(map compile-func prog)
;

;(define (build p)
;  (run (primpl-assemble (compile-simpl p))))
;
;;; tests for function
;(define arg-test-1 '((fun (f)(vars ()(return 1)))(fun (main)(vars ()(print (f))(return 0)))))
;(define arg-test-2 '((fun (f a)(vars ()(return a)))(fun (main)(vars ()(print (f 2))(return 0)))))
;(define arg-test-3 '((fun (f a b)(vars ()(return b)))(fun (main)(vars ()(print (f 3 3))(return 0)))))
;(define local-test-4 '((fun (f)(vars ([x 4])(return 4)))(fun (main)(vars ()(print (f))(return 0)))))
;
;(define bad-fun-1 '((fun ()(vars ()(return 1)))))
;(define bad-fun-2 '((fun (f)(vars ()))))
;(define bad-fun-3 '((fun (f)(vars (return 1)))))
;(define bad-fun-4 '((fun (f)(return 1))))
;(define bad-fun-5 '((fun (f)(vars ()(return 1)))))
;
;
;(define bad-app-1 '((fun (f)(vars ()(return 1)))(fun (main)(vars ()(print (f 1))(return 0)))))
;(define bad-app-2 '((fun (f a)(vars ()(return a)))(fun (main)(vars ()(print (f))(return 0)))))
;(define bad-app-3 '((fun (f a b)(vars ()(return b)))(fun (main)(vars ()(print (f 3 3 4))(return 0)))))
;
;;; tests for iif
;(define iif-test-1 '((fun (main)(vars ()(iif true (print 1) (print 0))(return 0)))))
;(define iif-test-2 '((fun (main)(vars ()(iif false (print 0) (print 2))(return 0)))))
;(define iif-test-3 '((fun (main)(vars ()(iif (< 0 3) (print 3) (print 2))(return 0)))))
;(define iif-test-4 '((fun (main)(vars ()(iif (not (< 0 3)) (print 3) (print 4))(return 0)))))
;
;;; test for arithmatic
;
;(define arth-test-1 '((fun (main) (vars () (print 1)(return 0)))))
;(define arth-test-2 '((fun (main) (vars () (print (+ 1 1))(return 0)))))
;(define arth-test-3 '((fun (main) (vars () (print (+ (* 2 1) 1))(return 0)))))
;(define arth-test-4 '((fun (main) (vars () (print (+ (* 2 1) (div 4 2)))(return 0)))))
;
;(define set-test-1 '((fun (f x y)
;              (vars ([i 0] [j 10])
;                    (set i j)
;                    (set j (+ y x))
;                    (print i) (print "\n")
;                    (print j) (print "\n")
;                    (return (div i j))))
;         (fun (main) (vars ([n 3] [e 5] [q 0])
;                           (set q (f n e))
;                           (return (f q e))))))
;
;
;(build set-test-1)
