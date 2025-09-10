(ns meuse.api.crate.sparse-test
  (:require [meuse.api.crate.sparse :refer :all]
            [meuse.path :as path]
            [meuse.db.public.crate :refer [crate-db]]
            [meuse.helpers.fixtures :refer :all]
            [clojure.test :refer :all]
            [cheshire.core :as json]
            [clojure.java.io :as io]
            [meuse.api.crate.http :refer [crates-api!]])
  (:import clojure.lang.ExceptionInfo))

(use-fixtures :once system-fixture)
(use-fixtures :each tmp-fixture)

(deftest get-config-test
  (testing "config.json file"
    (let [config {:dl "http://localhost/api/v1/crates"
                 :api "http://localhost"}
          config-path (path/new-path tmp-dir "config.json")]
      ;; Create config.json file
      (spit config-path (json/generate-string config))
      
      ;; Test config retrieval
      (let [request {:metadata-path tmp-dir}
            response (get-config request)]
        (is (= 200 (:status response)))
        (is (= "application/json" (get-in response [:headers "Content-Type"])))
        (is (= config (json/parse-string (:body response) true)))))))

(deftest get-index-one-char-test
  (testing "path parsing"
    (let [request {:uri "/1/z"}
          response (get-index-one-char crate-db request)]
      (is (= 404 (:status response)))))

  (testing "invalid path"
    (let [request {:uri "/1/abc"}
          response (get-index-one-char crate-db request)]
      (is (= 404 (:status response))))))

(deftest crates-api-config-test
  (testing "config endpoint"
    (let [config {:dl "http://localhost/api/v1/crates"
                 :api "http://localhost"}
          config-path (path/new-path tmp-dir "config.json")]
      ;; Create config.json file
      (spit config-path (json/generate-string config))
      
      ;; Test via crates-api! handler
      (let [response (crates-api! {:action :config
                                  :metadata-path tmp-dir
                                  :server-name "localhost"
                                  :server-port 8855})]
        (is (= 200 (:status response)))
        (is (= "application/json" (get-in response [:headers "Content-Type"])))
        (is (= config (json/parse-string (:body response) true)))))))