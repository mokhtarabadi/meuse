(ns meuse.config-test
    (:require [clojure.java.io :as io]
      [clojure.string :as str]
      [clojure.test :refer [deftest is testing]]
      [meuse.config :as config]))

;; Helper function for testing
(defn- with-temp-file [content f]
       (let [temp-file (File/createTempFile "config-test" ".yaml")]
            (try
              (spit temp-file content)
              (f (.getAbsolutePath temp-file))
              (finally
                (.delete temp-file)))))

(deftest test-convert-string-to-appropriate-type
         (testing "Converting string values to appropriate types"
                  (let [convert-fn #'config/convert-string-to-appropriate-type]
                       ;; Test boolean conversion
                       (is (true? (convert-fn "true")))
                       (is (true? (convert-fn "TRUE")))
                       (is (true? (convert-fn "True")))
                       (is (false? (convert-fn "false")))
                       (is (false? (convert-fn "FALSE")))
                       (is (false? (convert-fn "False")))

                       ;; Test nil conversion
                       (is (nil? (convert-fn "nil")))
                       (is (nil? (convert-fn "NIL")))
                       (is (nil? (convert-fn "Nil")))

                       ;; Test integer conversion
                       (is (= 123 (convert-fn "123")))
                       (is (= -456 (convert-fn "-456")))

                       ;; Test decimal conversion
                       (is (= 123.45 (convert-fn "123.45")))
                       (is (= -456.78 (convert-fn "-456.78")))

                       ;; Test string values that should remain strings
                       (is (= "hello" (convert-fn "hello")))
                       (is (= "123abc" (convert-fn "123abc")))

                       ;; Test non-string values
                       (is (= 123 (convert-fn 123)))
                       (is (= true (convert-fn true)))
                       (is (= nil (convert-fn nil))))))

(deftest test-convert-config-types
         (testing "Converting configuration map with nested values"
                  (let [convert-fn #'config/convert-config-types
                        input-config {:database {:port          "5432"
                                                 :max-pool-size "10"}
                                      :http     {:port "8855"}
                                      :frontend {:enabled "true"
                                                 :public  "false"}
                                      :array    ["1" "2" "3"]}
                        expected {:database {:port          5432
                                             :max-pool-size 10}
                                  :http     {:port 8855}
                                  :frontend {:enabled true
                                             :public  false}
                                  :array    [1 2 3]}]
                       (is (= expected (convert-fn input-config))))))

(deftest test-load-config-with-env-vars
         (testing "Loading configuration with environment variables"
                  (with-temp-file "database:\n  user: !envvar USER\n  password: !envvar PASSWORD\n  host: !envvar HOST\n  port: !envvar PORT\n  name: !envvar DB_NAME\n  max-pool-size: !envvar POOL_SIZE\nhttp:\n  address: \"0.0.0.0\"\n  port: !envvar HTTP_PORT\nlogging:\n  level: \"info\"\n  console:\n    encoder: \"json\"\nmetadata:\n  type: \"jgit\"\n  path: \"/tmp\"\n  target: \"master\"\n  url: \"http://example.com\"\n  username: \"user\"\n  password: \"pass\"\ncrate:\n  store: \"filesystem\"\n  path: \"/tmp\"\nfrontend:\n  enabled: !envvar FRONTEND_ENABLED\n  public: !envvar FRONTEND_PUBLIC\n  secret: \"abcdefghijklmnopqrstuvwxyz1234\"\n"
                                  (fn [config-path]
                                      ;; Set environment variables for the test
                                      (with-redefs [environ.core/env (merge environ.core/env
                                                                            {"user"             "testuser"
                                                                             "password"         "testpass"
                                                                             "host"             "localhost"
                                                                             "port"             "5432"
                                                                             "db-name"          "testdb"
                                                                             "pool-size"        "10"
                                                                             "http-port"        "8855"
                                                                             "frontend-enabled" "true"
                                                                             "frontend-public"  "false"})
                                                    config/stop! (fn [] (throw (Exception. "Config loading failed")))
                                                    yummy.config/load-config (fn [opts]
                                                                                 {:database {:user          "testuser"
                                                                                             :password      "testpass"
                                                                                             :host          "localhost"
                                                                                             :port          "5432"
                                                                                             :name          "testdb"
                                                                                             :max-pool-size "10"}
                                                                                  :http     {:address "0.0.0.0"
                                                                                             :port    "8855"}
                                                                                  :logging  {:level   "info"
                                                                                             :console {:encoder "json"}}
                                                                                  :metadata {:type     "jgit"
                                                                                             :path     "/tmp"
                                                                                             :target   "master"
                                                                                             :url      "http://example.com"
                                                                                             :username "user"
                                                                                             :password "pass"}
                                                                                  :crate    {:store "filesystem"
                                                                                             :path  "/tmp"}
                                                                                  :frontend {:enabled "true"
                                                                                             :public  "false"
                                                                                             :secret  "abcdefghijklmnopqrstuvwxyz1234"}})
                                                    yummy.config/validate (fn [_ _] true)
                                                    unilog.config/start-logging! (fn [_] nil)
                                                    meuse.log/info (fn [_ _] nil)]
                                                   (let [loaded-config (config/load-config config-path)]
                                                        ;; Check that values were properly converted to their correct types
                                                        (is (= 5432 (get-in loaded-config [:database :port])))
                                                        (is (= 10 (get-in loaded-config [:database :max-pool-size])))
                                                        (is (= 8855 (get-in loaded-config [:http :port])))
                                                        (is (true? (get-in loaded-config [:frontend :enabled])))
                                                        (is (false? (get-in loaded-config [:frontend :public])))))))))

(deftest test-load-config
         (with-redefs [config/stop! (fn [] (throw (Exception. "Config loading failed")))]
                      (try
                        (config/load-config "/this/path/does/not/exist")
                        (is (= 1 2))
                        (catch Exception _
                          (is true)))))
