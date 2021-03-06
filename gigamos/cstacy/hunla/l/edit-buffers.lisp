;;;-*- Mode:LISP; Package:ZWEI; Base:10; Readtable:CL -*-

; To Do: Refind File, Toggle Read-Only.


(DEFVAR *HACK-BUFFERS-SAVE-DIRTY* NIL)
(DEFVAR *HACK-BUFFERS-REQUIRES-CONFIRMATION-P* T)

(DEFMAJOR COM-HACK-BUFFERS-MODE HACK-BUFFERS-MODE "Hack-buffers"
  "Setup for editing the list of ZMACS buffers"
  ()
  (SET-COMTAB *MODE-COMTAB* '(#\SPACE   COM-HACK-BUFFERS-SELECT-AND-EXIT
                              #\D       COM-HACK-BUFFERS-DELETE
                              #\c-D     COM-HACK-BUFFERS-DELETE-AND-SAVE
                              #\d       (0 #\D)
                              #\S       COM-EDIT-BUFFERS-SAVE
                              #\s       (0 #\S) ;
                              #\U       COM-EDIT-BUFFERS-UNDELETE
                              #\u       (0 #\U)
                              #\RUBOUT  COM-EDIT-BUFFERS-REVERSE-UNDELETE
                              #\~       COM-EDIT-BUFFERS-UNMODIFY
                              #\N       COM-HACK-BUFFERS-NO-FILE-IO
                              #\n       (0 #\N)
                              #\R       COM-EDIT-BUFFERS-REVERT
                              #\r       (0 #\R)
                              #\ABORT   COM-EDIT-BUFFERS-ABORT
                              #\END     COM-EDIT-BUFFERS-EXIT
                              #\HELP    COM-HACK-BUFFERS-HELP
                              #\m->     COM-EDIT-BUFFERS-GOTO-END
                              #\m-<     COM-EDIT-BUFFERS-GOTO-BEGINNING))
  (SET-MODE-LINE-LIST (APPEND (MODE-LINE-LIST) '("   End to exit, Abort to cancel"))))

(DEFCOM COM-HACK-BUFFERS "Edit the list of buffers; save, kill, etc." ()
  (KILL-NEW-BUFFER-ON-ABORT (*INTERVAL*)
    (LET ((*INTERVAL* (OR (SEND SELF :FIND-SPECIAL-BUFFER :HACK-BUFFERS NIL "Hack-buffers" T)
                *INTERVAL*)))
      (MAKE-BUFFER-READ-ONLY *INTERVAL*)
      (COM-HACK-BUFFERS-MODE)
      (HACK-BUFFERS-REVERT *INTERVAL*)))
  DIS-NONE)

(DEFCOM COM-HACK-BUFFERS-HELP "Explain Edit Buffers commands." ()
  (FORMAT T "You are inside Edit Buffers.  You are editing a list of all ZMACS buffers.
You can move around in the list with the usual cursor motion commands.
Also, you can request to save, write, kill or unmodify buffers.

        D       Mark the buffer to be killed.
        c-D     Mark the buffer to be killed, after saving if modified
                Use N to cancel the saving but not cancel the killing.
        S       Mark the buffer to be saved.
        U       Cancel all operations on the buffer.
        Rubout  Cancel all operations on previous line, moving up.
        ~~      Mark the buffer to be unmodified.
        N       Cancel any request for file I/O on the buffer.
        R       Mark the buffer to be reverted.

        End     Exit, performing the requested operations.
        Space   Exit as above, but selecting the buffer on this line.
        Abort   Exit, without taking any actions.
        Help    Give this information.


")
  DIS-NONE)

(DEFCOM COM-EDIT-BUFFERS-GOTO-END
        "Move to the last buffer line."
        ()
  (MOVE-BP (POINT) (INTERVAL-LAST-BP *INTERVAL*))
  (DOWN-REAL-LINE -3)
  DIS-BPS)


(DEFCOM COM-EDIT-BUFFERS-GOTO-BEGINNING
        "Move to the first buffer line."
        ()
  (MOVE-BP (POINT) (INTERVAL-FIRST-BP *INTERVAL*))
  (DOWN-REAL-LINE 3)
  DIS-BPS)

(DEFUN HACK-BUFFERS-REVERT (BUFFER &KEY (SAVE-DIRTY *HACK-BUFFERS-SAVE-DIRTY*) SELECTP)
  (WITH-READ-ONLY-SUPPRESSED (BUFFER)
    (LET* ((*INTERVAL* BUFFER)
           (BUFFERS (BUFFER-LIST-AS-SELECTED))
           (OLD-BUFFER (SECOND BUFFERS))
           (*BATCH-UNDO-SAVE* T))
      (DELETE-INTERVAL *INTERVAL*)
      (DISCARD-UNDO-INFORMATION *INTERVAL*)
      (LET* ((STREAM (INTERVAL-STREAM-INTO-BP (INTERVAL-FIRST-BP *INTERVAL*)))
             (MAX-SIZE 40.)
             (VERSION-POS (+ MAX-SIZE 6))
             ;; The following flags are set when we use a funny character in our
             ;; display, so that we can remember to explain it to the luser.
             CIRCLE-PLUS-FLAG STAR-FLAG PLUS-FLAG EQV-FLAG)
        (FORMAT STREAM "~&Zmacs Buffers:~%  Buffer name:~vTFile Version:~%" (- VERSION-POS 2))
        (DOLIST (BUFFER *ZMACS-BUFFER-LIST*)
          (UNLESS (EQ BUFFER *INTERVAL*)
            (LET ((FILE-ID (BUFFER-FILE-ID BUFFER))
                  (MAJOR-MODE (BUFFER-MAJOR-MODE BUFFER)))
              (MULTIPLE-VALUE-BIND (NAME TRUNCATED?)
                  (NAME-FOR-DISPLAY BUFFER MAX-SIZE)
                (MACROLET ((OR-FLAG (FLAG-VAR FLAG-FORM)
                                    (ONCE-ONLY (FLAG-FORM)
                                      `(PROGN (SETQ ,FLAG-VAR (OR ,FLAG-VAR ,FLAG-FORM))
                                              ,FLAG-FORM))))
                  (OR-FLAG CIRCLE-PLUS-FLAG TRUNCATED?)
                  (FORMAT STREAM "~%~:[~;S~]~:[~;.~]~4T~:[~;~]~:[~;*~]~:[~;+~]"
                          (AND SAVE-DIRTY (BUFFER-NEEDS-SAVING-P BUFFER))       ;Notice dirty, and mark.
                          (EQ BUFFER OLD-BUFFER)
                          (OR-FLAG EQV-FLAG (BUFFER-READ-ONLY-P BUFFER))
                          (OR-FLAG STAR-FLAG (BUFFER-MODIFIED-P BUFFER))
                          (OR-FLAG PLUS-FLAG (EQ FILE-ID T))))
                (COND ((MEMQ MAJOR-MODE '(DIRED-MODE BDIRED-MODE))
                       (FORMAT STREAM "~6T~A~VT~A"
                               NAME VERSION-POS (BUFFER-PATHNAME BUFFER)))
                      ((MEMQ MAJOR-MODE '(POSSIBILITIES-MODE))
                       (FORMAT STREAM "~6T~A~VT~A"
                               NAME VERSION-POS (POSSIBILITIES-BUFFER-TITLE BUFFER)))
                      ((AND FILE-ID
                            (NOT (EQ FILE-ID T)))
                       (FORMAT STREAM "~6T~A~VT~A"
                               NAME VERSION-POS (BUFFER-VERSION-STRING BUFFER)))
                      (T
                       (FORMAT STREAM "~6T~A" NAME))))
              (FORMAT STREAM "~vT~D Line~:P~vT(~A)"
                      (+ VERSION-POS 32.)
                      (COUNT-LINES-BUFFER BUFFER)
                      (+ VERSION-POS 44.)
                      (SYMEVAL MAJOR-MODE)))
            (SEND STREAM :LINE-PUT 'BUFFER BUFFER)))    ;Remember ths buffer on this line.
        (FORMAT STREAM "~2%")
        (WHEN CIRCLE-PLUS-FLAG (FORMAT STREAM "  means name truncated   "))
        (WHEN PLUS-FLAG        (FORMAT STREAM "+ means new file   "))
        (WHEN STAR-FLAG        (FORMAT STREAM "* means buffer modified.   "))
        (WHEN EQV-FLAG         (FORMAT STREAM " means read-only   "))
        (TERPRI STREAM))
      (COM-EDIT-BUFFERS-GOTO-BEGINNING)))
  (WHEN SELECTP
    (MAKE-BUFFER-CURRENT BUFFER)))

(DEFUN POSSIBILITIES-BUFFER-TITLE (BUFFER)
  (LET ((TITLE (BP-LINE (INTERVAL-FIRST-BP BUFFER))))
    (SUBSTRING TITLE 0 (MIN (LENGTH TITLE) 30))))

(DEFCOM COM-HACK-BUFFERS-EXIT
        "Perform the indicated operations, then exit."
        ()
  (HACK-BUFFERS-EXIT)
  DIS-BPS)

(DEFCOM COM-HACK-BUFFERS-SELECT-AND-EXIT
        "Perform the indicated operations, then exit, selecting the buffer on the current line."
        ()
  (HACK-BUFFERS-EXIT (EDIT-BUFFERS-LINE-BUFFER (BP-LINE (POINT))))
  DIS-BPS)

(DEFUN HACK-BUFFERS-EXIT (&OPTIONAL BUFFER-TO-SELECT (CONFIRM *HACK-BUFFERS-REQUIRES-CONFIRMATION-P*))
  (DO ((LINE (BP-LINE (INTERVAL-FIRST-BP *INTERVAL*)) (LINE-NEXT LINE))
       (LAST-LINE (BP-LINE (INTERVAL-LAST-BP *INTERVAL*)))
       (BUFFERS-TO-SAVE NIL)
       (BUFFERS-TO-REVERT NIL)
       (BUFFERS-TO-UNMODIFY NIL)
       (BUFFERS-TO-KILL NIL))
      ((EQ LINE LAST-LINE)
       (WHEN (OR (NOT CONFIRM)
                 (AND (NULL BUFFERS-TO-SAVE)
                      (NULL BUFFERS-TO-KILL))
                 (LET ((*QUERY-IO* *STANDARD-OUTPUT*))  ;Use typeout window.
                   (YES-OR-NO-P "~%~@[~%Buffers to be saved: ~%~4T~{~A~^~&~}~]~
                                   ~@[~%Buffers to be killed:~%~4T~{~A~^~&~}~]~
                                 ~2%Okay? "
                                BUFFERS-TO-SAVE BUFFERS-TO-KILL)))
         (DOLIST (B BUFFERS-TO-SAVE) (SAVE-BUFFER B))
         (DOLIST (B BUFFERS-TO-REVERT) (REVERT-BUFFER B))
         (DOLIST (B BUFFERS-TO-UNMODIFY) (NOT-MODIFIED B))
         (DOLIST (B BUFFERS-TO-KILL) (KILL-BUFFER B T))
         (SEND SELF :EXIT-SPECIAL-BUFFER T *INTERVAL*)
         (WHEN BUFFER-TO-SELECT
           (MAKE-BUFFER-CURRENT BUFFER-TO-SELECT))))
    (LET ((BUFFER (EDIT-BUFFERS-LINE-BUFFER LINE)))
      (WHEN BUFFER
        (CASE (CHAR LINE 1)
          (#\S (PUSH BUFFER BUFFERS-TO-SAVE))
          (#\R (PUSH BUFFER BUFFERS-TO-REVERT ))
          (#\~ (PUSH BUFFER BUFFERS-TO-UNMODIFY)))
        (CASE (CHAR LINE 0)
          (#\D (PUSH BUFFER BUFFERS-TO-KILL)))))))


(DEFCOM COM-HACK-BUFFERS-DELETE
        "Mark buffer(s) for deletion."
        ()
  (EDIT-BUFFERS-MAP-OVER-LINES
    *NUMERIC-ARG*
    #'(LAMBDA (LINE)
        (MUNG-LINE LINE)
        (SETF (CHAR LINE 0) #\D))))

(DEFCOM COM-HACK-BUFFERS-DELETE-AND-SAVE
        "Mark buffer(s) for deletion, and saving if modified."
        ()
  (EDIT-BUFFERS-MAP-OVER-LINES
    *NUMERIC-ARG*
    #'(LAMBDA (LINE)
        (MUNG-LINE LINE)
        (SETF (CHAR LINE 0) #\D)
        (WHEN (BUFFER-NEEDS-SAVING-P (EDIT-BUFFERS-LINE-BUFFER LINE))
          (SETF (CHAR LINE 1) #\S)))))

(DEFCOM COM-HACK-BUFFERS-NO-FILE-IO
        "Mark buffer(s) not to be saved, reverted, etc."
        ()
  (EDIT-BUFFERS-MAP-OVER-LINES
    (IF (AND (NOT *NUMERIC-ARG-P*)
             (> (STRING-LENGTH (BP-LINE (POINT))) 3)
             (CHAR= #\Space (CHAR (BP-LINE (POINT)) 1)))
        -1
      *NUMERIC-ARG*)
    (LAMBDA (LINE)
      (MUNG-LINE LINE)
      (SETF (CHAR LINE 0) #\Space)
      (SETF (CHAR LINE 1) #\Space))))


;;;; Edit history for HUNLA:L;EDIT-BUFFERS.LISP.14
;;;
;;; [10/25/88 21:05 CStacy] This is a better mode for editing buffers.
;;; [10/27/88 03:09 CStacy] Hack confirmation, and clean up the comtab.
