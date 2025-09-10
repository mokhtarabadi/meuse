(ns meuse.api.crate.sparse_test
  (:require [meuse.api.crate.sparse :refer :all]
            [meuse.path :as path]
            [meuse.helpers.fixtures :refer :all]
            [clojure.test :refer :all]
            [cheshire.core :as json]
            [clojure.java.io :as io])
  (:import clojure.lang.ExceptionInfo))

(use-fixtures :once system-fixture)
(use-fixtures :each tmp-fixture db-clean-fixture table-fixture)

(deftest get-crate-index-test
  (testing "existing crate"
    ;; Use the existing crate1 from table-fixture
    ;; Test retrieval
    (let [request {}
          response (get-crate-index crate-db request "crate1")]
      (is (= 200 (:status response)))
      (is (= "application/json" (get-in response [:headers "Content-Type"])))
      (is (get-in response [:headers "ETag"]))
      (is (= "public, max-age=3600" (get-in response [:headers "Cache-Control"])))
      
      ;; Test response body contains versions
      (let [body (:body response)
            lines (clojure.string/split-lines body)
            versions (map #(json/parse-string % true) lines)]
        (is (= 3 (count versions)))
        (is (some #(= "1.1.0" (:vers %)) versions))
        (is (some #(= "1.1.4" (:vers %)) versions))
        (is (some #(= "1.1.5" (:vers %)) versions))
        (is (every? #(= "crate1" (:name %)) versions)))))

  (testing "non-existent crate"
    (let [request {}
          response (get-crate-index crate-db request "nonexistent")]
      (is (= 404 (:status response))))))

(deftest get-index-one-char-test
  (testing "valid one-char crate"
    ;; Insert test crate into database
    (crate-db/create database {:name "z" :description "A one-char crate"})
    (crate-version-db/create database {:crate-id 2 :version "0.1.0" :yanked false :description "Initial version"})
    
    ;; Test retrieval via HTTP endpoint
    (let [request {:uri "/1/z"}
          response (get-index-one-char crate-db request)]
      (is (= 200 (:status response)))
      (is (= "application/json" (get-in response [:headers "Content-Type"])))
      (is (get-in response [:headers "ETag"]))
      
      ;; Check response contains the version
      (let [body (:body response)
            lines (clojure.string/split-lines body)
            versions (map #(json/parse-string % true) lines)]
        (is (= 1 (count versions)))
        (is (= "z" (:name (first versions))))
        (is (= "0.1.0" (:vers (first versions)))))))

  (testing "invalid path"
    (let [request {:uri "/1/abc"}
          response (get-index-one-char crate-db request)]
      (is (= 404 (:status response)))))

(deftest crates-api-sparse-test
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
        (is (= config (json/parse-string (:body response) true))))))
  
  (testing "crate index endpoint"
    ;; Create test crate in database
    (crate-db/create database {:name "aa" :description "A two-char crate"})
    (crate-version-db/create database {:crate-id 3 :version "0.2.0" :yanked false :description "Two-char version"})
    
    ;; Test via crates-api! handler
    (let [response (crates-api! {:action :index-two-char
                                :uri "/2/aa"})]
      (is (= 200 (:status response)))
      (is (= "application/json" (get-in response [:headers "Content-Type"])))
      
      ;; Check response contains the version
      (let [body (:body response)
            lines (clojure.string/split-lines body)
            versions (map #(json/parse-string % true) lines)]
        (is (= 1 (count versions)))
        (is (= "aa" (:name (first versions))))
        (is (= "0.2.0" (:vers (first versions)))))))))