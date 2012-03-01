;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; Base: 10 -*-

;;; Copyright (c) 2009-2012 Gustavo Henrique Milaré
;;; See the file license for license information.

(in-package :decimal-floats)

(declaim (type (or (member :scientific :engineering :exponencia :signed-digits
                           :digits :unsigned-digits :signed-digits+exponent
                           :digits+exponent :unsigned-digits+exponent)
                   function) *printing-format*))

(defvar *printing-format* :scientific
  "The printing format to be used. It must either be a keyword or a function.
Accepted keywords are :SCIENTIFIC, :ENGINEERING, :EXPONENCIAL :SIGNED-DIGITS,
:DIGITS, :UNSIGNED-DIGITS, :SIGNED-DIGITS+EXPONENT, :DIGITS+EXPONENT, and
:UNSIGNED-DIGITS+EXPONENT.

Scientific format: http://speleotrove.com/decimal/daconvs.html#reftostr
Engineering format: http://speleotrove.com/decimal/daconvs.html#reftoeng

You can create a custom printing format by using a function.
Information on how to create a printing format function is in the file
\"doc/printing-format\".

Note that some formats may break readability (i.e. the number that is read back
may not be the same). If readability is needed, use one of the following formats:
:scientific, :engineering, :exponencial, :signed-digits+exponent or
:digits+exponent

The method of PRINT-OBJECT for DECIMAL-FLOAT may ignore this value if
*PRINT-READABLY* is true.")

(def-customize-function find-printing-format (exponent adj-exponent digits)
  (declare (type adjusted-exponent adj-exponent) ; can't do any better
           (type exponent exponent)
           (type fixnum digits)) ; omit the '-' sign?
  (:scientific (if (and (<= exponent 0)
                        (<= -6 adj-exponent))
                   (values nil
                           (if (zerop exponent)
                               nil
                               (+ digits exponent))
                           :exponent)
                   (values (if (zerop adj-exponent)
                               nil
                               adj-exponent)
                           (if (= 1 digits)
                               nil
                               1)
                           :exponent)))
  (:engineering (if (and (<= exponent 0)
                         (<= -6 adj-exponent))
                    (values nil (+ digits exponent) :exponent)
                    (let* ((adjust (mod adj-exponent 3)))
                      (decf adj-exponent adjust)
                      (values (if (zerop adj-exponent)
                                  nil
                                  adj-exponent)
                              (+ 1 adjust)
                              :exponent))))
  (:exponencial (values adj-exponent 1))
  (:signed-digits (values nil nil t))
  (:digits (values))
  (:unsigned-digits (values nil nil nil t))
  (:signed-digits+exponent (values exponent nil :coefficient))
  (:digits+exponent (values exponent nil nil nil))
  (:unsigned-digits+exponent (values exponent nil nil t)))

(defun decimal-dispatch-macro-character (stream char depth)
  (declare (ignore char depth))
  (let ((string (with-output-to-string (output)
                  (loop for char = (read-char stream nil #\  stream)
                     while (or (alphanumericp char)
                               (member char '(#\+ #\- #\.)))
                     do (write-char char output)))))
    (with-condition-trap-enablers ('(decimal-invalid-operation))
      (parse-decimal string :round-p nil))))

(set-dispatch-macro-character #\# #\$ #'decimal-dispatch-macro-character)

(defmethod print-object ((x decimal-float) stream)
  (write-string "#$" stream)
  (print-decimal x stream
                 :format
                 (if *print-readably*
                     :scientific
                     *printing-format*)))

(defun print-decimal (x stream &key (format *printing-format*)
                      (nan-diagnostic-p t))
  "Prints the decimal X to STREAM. FORMAT should be either a keyword specifying
a standard format or a function.

The standard printing format functions are accessible through the
funtion GET-PRINTING-FORMAT."
  (let (print-plus-p omit-minus-p printed-exp dot-position)
    (with-inf-nan-handler
        (x :inf-around (write-string (call-next-handler) stream)
           :inf-before (setf (values printed-exp dot-position print-plus-p omit-minus-p)
                             (find-printing-format format 0 1 0))
           :+infinity (if (member print-plus-p '(t :coefficient))
                          "+Infinity"
                          "Infinity")
           :-infinity (if (member omit-minus-p '(t :coefficient))
                          "Infinity"
                          "-Infinity")
           :qnan (if (df-negative-p x)
                     (if (not (member omit-minus-p '(t :coefficient)))
                         "-NaN"
                         "NaN")
                     (if (member print-plus-p '(t :coefficient))
                         "+NaN"
                         "NaN"))
           :snan (if (df-negative-p x)
                     (if (not (member omit-minus-p '(t :coefficient)))
                         "-sNaN"
                         "sNaN")
                     (if (member print-plus-p '(t :coefficient))
                         "+sNaN"
                         "sNaN"))
           :nan-before (setf (values printed-exp dot-position print-plus-p omit-minus-p)
                             (find-printing-format format 0 0 0))
           ;; prints "NaN" or "sNaN", according to NaN type
           :nan-around (write-string (call-next-handler) stream)
           ;; prints NaN diagnostic number, if any
           :nan-after (when nan-diagnostic-p
                        (when-let ((x-slots (df-slots x)))
                          (%print-decimal stream (df-count-digits x) x-slots
                                          (df-first-slot-last-digit x)
                                          (df-last-slot-first-digit x)
                                          nil nil nil nil))))
      (multiple-value-bind (digits exponent adj-exponent x-slots fsld lsfd)
          (parse-info x)
        (setf (values printed-exp dot-position print-plus-p omit-minus-p)
              (find-printing-format format exponent adj-exponent digits))
        ;; prints the negative sign, if any
        (cond
          ((df-negative-p x)
           (when (not (member omit-minus-p '(t :coefficient)))
             (write-char #\- stream)))
          ((member print-plus-p '(t :coefficient))
           (write-char #\+ stream)))
        ;; prints the rest
        (%print-decimal stream digits x-slots fsld lsfd
                        printed-exp dot-position print-plus-p omit-minus-p))))
  (force-output stream)
  x)

(declaim (inline decimal-to-string))

(defun decimal-to-string (x &rest keys)
  (with-output-to-string (stream)
    (apply #'print-decimal x stream keys)))

(defun %print-decimal (stream digits x-slots fsld lsfd
                       printed-exp dot-position print-plus-p omit-minus-p)
  (let* ((dot-position (or dot-position digits))
         (buffer (make-string (max (+ 2 digits (abs dot-position))
                                   (1+ +decimal-slot-digits+))
                              :element-type 'base-char :initial-element #\0)))
    (let ((pos 0))
      ;; prints zeroes up to the digits of the number, if any
      (when (<= dot-position 0)
        (setf (char buffer 1) #\.
              pos (- 2 dot-position)))
      ;; prints the digits of the number
      (map-digits-array #'(lambda (digit)
                            (when (= dot-position pos)
                              (setf (char buffer pos) #\.)
                              (incf pos))
                            (setf (char buffer pos) (digit-char digit))
                            (incf pos))
                        x-slots fsld lsfd nil)
      (when (> dot-position pos)
        (fill buffer #\0 :start pos :end dot-position)
        (setf pos dot-position))
      (write-string buffer stream :end pos))
    ;; prints the exponent, if any
    (when printed-exp
      (write-char #\E stream)
      (cond
        ((minusp printed-exp)
         (when (member omit-minus-p '(t :exponent))
           (setf printed-exp (abs printed-exp))))
        ((member print-plus-p '(t :exponent))
         (write-char #\+ stream)))
      (format stream "~10r" printed-exp))))

(defun parse-decimal (string &key (start 0) (end (length string)) (round-p t)
                      (trim-spaces t))
  (with-operation (parse-decimal condition (subseq string start (or end (length string))))
      ((decimal-conversion-syntax (make-nan nil nil)))
    (when trim-spaces
      (setf start (or (position-if (complement #'whitespace-p)
                                   string :start start :end end)
                      end))
      (when-let (new-end (position-if (complement #'whitespace-p)
                                      string :start start :end end :from-end t))
        (setf end (1+ new-end))))
    (unless (< -1 start end)
      (decimal-error-cond (nil :return-p t)
        decimal-conversion-syntax))
    (let* ((position start)
           (signed-p (case (char string start)
                       (#\+ (incf position) nil)
                       (#\- (incf position) t)
                       (t nil))))
      (if (alpha-char-p (char string position))
          (let* ((pos (mismatch "nan" string :start2 position :end2 end
                                :test #'char-equal))
                 (poss (mismatch "snan" string :start2 position :end2 end
                                 :test #'char-equal))
                 (signaling-p (when (or (not poss) (= poss 4))
                                (setf pos poss)
                                t)))
            (cond ((or (null pos) (= pos 3) signaling-p)
                   (let ((nan (make-nan signed-p signaling-p)))
                     ;; Read NaN diagnostic message.
                     (when pos
                       (incf position pos)
                       ;; Rounding NaN diagnostic message is not allowed.
                       (when (or (and round-p (> (- end start) *precision*))
                                 (find-if (complement #'digit-char-p) string
                                          :start position :end end))
                         (decimal-error-cond (nil :return-p t)
                           decimal-conversion-syntax))
                       (let ((position (position #\0 string :start position :end end
                                                 :test-not #'char=)))
                         (when position
                           (multiple-value-bind (iexponent slots fsld lsfd)
                               (%parse-decimal string position end)
                             (declare (ignore iexponent))
                             (setf (df-slots nan) slots
                                   (df-first-slot-last-digit nan) fsld
                                   (df-last-slot-first-digit nan) lsfd)))))
                     nan))
                  ((or (string-equal "inf" string :start2 position :end2 end)
                       (string-equal "infinity" string :start2 position :end2 end))
                   (make-infinity signed-p))
                  (t
                   (decimal-error-cond (nil :return-p t)
                     decimal-conversion-syntax))))
          (multiple-value-bind (iexponent slots fsld lsfd)
              (%parse-decimal string position end)
            (declare (ignore lsfd))
            (let ((*precision* (if round-p
                                   *precision*
                                   (length string))))
              (values
               (normalize-number iexponent slots fsld signed-p)
               ;; Following convention of PARSE-INTEGER
               end)))))))

(defun %parse-decimal (string start end)
  (let* ((e-position (or (position #\e string :start start :end end :test #'char-equal)
                         end))
         (dot-position (or (position #\. string :start start :end e-position :test #'char=)
                           e-position))
         (digits (- e-position start
                    (if (< dot-position e-position) 1 0)))
         (printed-exp (cond
                        ((= e-position end) 0)
                        ((< e-position (1- end))
                         (unless (and (let ((char (char string (1+ e-position))))
                                        (or (digit-char-p char)
                                            (member char '(#\+ #\-))))
                                      (digit-char-p (char string (1- end))))
                           ;; PARSE-INTEGER accepts leading and trailing whitespaces
                           ;; while %PARSE-DECIMAL doesn't
                           (decimal-error-cond (nil :return-p t)
                             decimal-conversion-syntax))
                         (handler-case (parse-integer string :start (1+ e-position)
                                                      :end end)
                           (parse-error ()
                             (decimal-error-cond (nil :return-p t)
                               decimal-conversion-syntax))))
                        ;; There is an "E" but no exponent after it
                        (t (decimal-error-cond (nil :return-p t)
                             decimal-conversion-syntax)))))
    (unless (plusp digits)
      (decimal-error-cond (nil :return-p t)
        decimal-conversion-syntax))
    (multiple-value-bind (slots fsld lsfd iexponent)
        (calculate-info digits printed-exp (- dot-position start))
      (let* ((position start)
             (slots (map-digits-array
                     #'(lambda (old-digit)
                         (declare (ignore old-digit))
                         (if (= position dot-position)
                             (incf position))
                         (prog1
                             (or (digit-char-p (char string position))
                                 (decimal-error-cond (nil :return-p t)
                                   decimal-conversion-syntax))
                           (incf position)))
                     slots fsld lsfd t)))
        (values iexponent slots fsld lsfd)))))
