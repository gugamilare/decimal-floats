;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

;;; Copyright (c) 2009-2013 Gustavo Henrique Milaré
;;; See the file license for license information.

(in-package :cl-user)

(defpackage :decimal-floats
  (:use :cl :alexandria)
  (:export
   ;; Constants
   #:+maximum-exponent+ #:+minimum-exponent+ #:+maximum-precision+ #:+minimum-precision+
   ;; Structure
   #:decimal-float #:exponent #:adjusted-exponent

   ;; Conditions
   #:+all-conditions+
   #:decimal-float-condition
   #:decimal-clamped #:decimal-division-by-zero #:decimal-inexact
   #:decimal-invalid-operation
   #:decimal-overflow #:decimal-rounded #:decimal-subnormal #:decimal-underflow
   #:decimal-conversion-syntax
   #:decimal-division-impossible #:decimal-division-undefined

   #:operation-name #:operation-defined-result #:operation-arguments
   #:return-defined-result #:return-another-value

   #:*condition-flags* #:*condition-trap-enablers*
   #:get-condition-flags #:get-condition-trap-enablers #:find-condition-flags
   #:find-condition-trap-enablers
   #:with-condition-flags #:with-condition-flags* #:with-condition-trap-enablers

   ;; Rounding
   #:*precision* #:precision
   #:*rounding-mode*

   ;; Printing
   #:*printing-format*
   #:print-decimal #:decimal-to-string #:parse-decimal

   ;; Conversions
   #:decimal-to-integer #:integer-to-decimal
   #:decimal-to-float   #:float-to-decimal

   ;; Basic Operations
   #:finite-p #:infinite-p #:nan-p #:snan-p #:qnan-p #:subnormal-p #:normal-p
   #:zero-p #:signed-p #:same-quantum-p #:canonical-p #:canonical
   #:logb-int #:logb #:scaleb
   #:decimal-class #:decimal-class-string
   #:copy-decimal #:dec-abs #:copy-abs #:copy-sign #:copy-minus
   #:plus #:minus

   ;; Comparison
   #:maximum #:maximum-abs #:minimum #:minimum-abs
   #:compare #:compare-int #:compare-total #:compare-total-int
   #:compare-total-abs #:compare-total-abs-int))
