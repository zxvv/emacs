;;; sql-tests.el --- Tests for sql.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2016-2019 Free Software Foundation, Inc.

;; Author: Simen Heggestøyl <simenheg@gmail.com>
;; Keywords:

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'sql)

(ert-deftest sql-tests-postgres-list-databases ()
  "Test that output from `psql -ltX' is parsed correctly."
  (cl-letf
      (((symbol-function 'executable-find)
        (lambda (_command) t))
       ((symbol-function 'process-lines)
        (lambda (_program &rest _args)
          '(" db-name-1 | foo-user | UTF8     | en_US.UTF-8 | en_US.UTF-8 | "
            " db_name_2 | foo-user | UTF8     | en_US.UTF-8 | en_US.UTF-8 | "
            ""))))
    (should (equal (sql-postgres-list-databases)
                   '("db-name-1" "db_name_2")))))

(ert-deftest sql-tests-postgres-list-databases-error ()
  "Test that nil is returned when `psql -ltX' fails."
  (cl-letf
      (((symbol-function 'executable-find)
        (lambda (_command) t))
       ((symbol-function 'process-lines)
        (lambda (_program &rest _args)
          (error "some error"))))
    (should-not (sql-postgres-list-databases))))

(defvar sql-test-login-params nil)
(defmacro with-sql-test-connect-harness (id login-params connection expected)
  "Set-up and tear-down SQL connect related test.

Identify tests by ID.  Set :sql-login dialect attribute to
LOGIN-PARAMS.  Provide the CONNECTION parameters and the EXPECTED
string of values passed to the comint function for validation."
  (declare (indent 2))
  `(cl-letf
      ((sql-test-login-params ' ,login-params)
       ((symbol-function 'sql-comint-test)
        (lambda (product options &optional buf-name)
          (with-current-buffer (get-buffer-create buf-name)
            (insert (pp-to-string (list product options sql-user sql-password sql-server sql-database))))))
       ((symbol-function 'sql-run-test)
        (lambda (&optional buffer)
          (interactive "P")
          (sql-product-interactive 'sqltest buffer)))
       (sql-user nil)
       (sql-server nil)
       (sql-database nil)
       (sql-product-alist
        '((ansi)
          (sqltest
           :name "SqlTest"
           :sqli-login sql-test-login-params
           :sqli-comint-func sql-comint-test)))
       (sql-connection-alist
        '((,(format "test-%s" id)
           ,@connection)))
       (sql-password-wallet
        (list
         (make-temp-file
          "sql-test-netrc" nil nil
          (mapconcat #'identity
                     '("machine aMachine user aUserName password \"netrc-A aPassword\""
                       "machine aServer user aUserName password \"netrc-B aPassword\""
                       "machine aMachine server aServer user aUserName password \"netrc-C aPassword\""
                       "machine aMachine database aDatabase user aUserName password \"netrc-D aPassword\""
                       "machine aDatabase user aUserName password \"netrc-E aPassword\""
                       "machine aMachine server aServer database aDatabase user aUserName password \"netrc-F aPassword\""
                       "machine \"aServer/aDatabase\" user aUserName password \"netrc-G aPassword\""
                       ) "\n")))))

     (let* ((connection ,(format "test-%s" id))
            (buffername (format "*SQL: ERT TEST <%s>*" connection)))
       (when (get-buffer buffername)
         (kill-buffer buffername))
       (sql-connect connection buffername)
       (should (get-buffer buffername))
       (should (string-equal (with-current-buffer buffername (buffer-string)) ,expected))
       (when (get-buffer buffername)
         (kill-buffer buffername))
     (delete-file (car sql-password-wallet)))))

(ert-deftest sql-test-connect ()
  "Test of basic `sql-connect'."
  (with-sql-test-connect-harness 1 (user password server database)
      ((sql-product 'sqltest)
       (sql-user "aUserName")
       (sql-password "test-1 aPassword")
       (sql-server "aServer")
       (sql-database "aDatabase"))
    "(sqltest nil \"aUserName\" \"test-1 aPassword\" \"aServer\" \"aDatabase\")\n"))

(ert-deftest sql-test-connect-password-func ()
  "Test of password function."
  (with-sql-test-connect-harness 2 (user password server database)
      ((sql-product 'sqltest)
       (sql-user "aUserName")
       (sql-password (lambda () (concat [?t ?e ?s ?t ?- ?2 ?\s
                                       ?a ?P ?a ?s ?s ?w ?o ?r ?d])))
       (sql-server "aServer")
       (sql-database "aDatabase"))
    "(sqltest nil \"aUserName\" \"test-2 aPassword\" \"aServer\" \"aDatabase\")\n"))

(ert-deftest sql-test-connect-wallet-server-database ()
  "Test of password function."
  (with-sql-test-connect-harness 3 (user password server database)
      ((sql-product 'sqltest)
       (sql-user "aUserName")
       (sql-server "aServer")
       (sql-database "aDatabase"))
    "(sqltest nil \"aUserName\" \"netrc-G aPassword\" \"aServer\" \"aDatabase\")\n"))

(ert-deftest sql-test-connect-wallet-database ()
  "Test of password function."
  (with-sql-test-connect-harness 4 (user password database)
      ((sql-product 'sqltest)
       (sql-user "aUserName")
       (sql-database "aDatabase"))
    "(sqltest nil \"aUserName\" \"netrc-E aPassword\" nil \"aDatabase\")\n"))

(ert-deftest sql-test-connect-wallet-server ()
  "Test of password function."
  (with-sql-test-connect-harness 5 (user password server)
      ((sql-product 'sqltest)
       (sql-user "aUserName")
       (sql-server "aServer"))
    "(sqltest nil \"aUserName\" \"netrc-B aPassword\" \"aServer\" nil)\n"))

(provide 'sql-tests)
;;; sql-tests.el ends here
