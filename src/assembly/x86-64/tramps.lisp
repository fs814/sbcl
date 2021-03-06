;;;; Undefined-function and closure trampoline definitions

;;;; This software is part of the SBCL system. See the README file for
;;;; more information.

(in-package "SB!VM")

(define-assembly-routine
    (undefined-tramp (:return-style :none))
    ((:temp rax descriptor-reg rax-offset))
  #!+immobile-code
  (progn
    (inst pop rax) ; gets the address of the fdefn (plus some)
    (inst sub (reg-in-size rax :dword)
          ;; Subtract the length of the JMP instruction plus offset to the
          ;; raw-addr-slot, and add back the lowtag. Voila, a tagged descriptor.
          (+ 5 (ash fdefn-raw-addr-slot word-shift) (- other-pointer-lowtag))))
  (inst pop (make-ea :qword :base rbp-tn :disp n-word-bytes))
  (emit-error-break nil cerror-trap (error-number-or-lose 'undefined-fun-error) (list rax))
  (inst push (make-ea :qword :base rbp-tn :disp n-word-bytes))
  (inst jmp
        (make-ea :qword :base rax
                        :disp (- (* closure-fun-slot n-word-bytes)
                                 fun-pointer-lowtag))))

(define-assembly-routine
    (undefined-alien-tramp (:return-style :none))
    ()
  (inst pop (make-ea :qword :base rbp-tn :disp n-word-bytes))
  (error-call nil 'undefined-alien-fun-error rbx-tn))

;;; the closure trampoline - entered when a global function is a closure
;;; and the function is called "by name" (normally, as when it is the
;;; head of a form) via an FDEFN. Register %RAX holds the fdefn address,
;;; but the simple-fun which underlies the closure expects %RAX to be the
;;; closure itself. So we grab the closure out of the fdefn pointed to,
;;; then jump to the simple-fun that the closure points to.
(define-assembly-routine
    (closure-tramp (:return-style :none))
    ()
  (loadw rax-tn rax-tn fdefn-fun-slot other-pointer-lowtag)
  (inst jmp (make-ea-for-object-slot rax-tn closure-fun-slot fun-pointer-lowtag)))

(define-assembly-routine
    (funcallable-instance-tramp (:return-style :none))
    ()
  (loadw rax-tn rax-tn funcallable-instance-function-slot fun-pointer-lowtag)
  (inst jmp (make-ea-for-object-slot rax-tn closure-fun-slot fun-pointer-lowtag)))
