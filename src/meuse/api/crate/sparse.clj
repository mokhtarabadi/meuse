(ns meuse.api.crate.sparse
  "Implements the Cargo sparse registry protocol."
  (:require [meuse.crate :as crate]
            [meuse.db.public.crate :as public-crate]
            [meuse.db.actions.crate :as crate-db]
            [meuse.db.public.category :as public-category]
            [meuse.path :as path]
            [meuse.registry :as registry]
            [meuse.http :as http]
            [ring.util.response :as ring]
            [clojure.string :as string]
            [cheshire.core :as json]
            [clojure.java.io :as io]
            [clojure.tools.logging :as log]))

(defn get-config
  "Return the config.json file for the sparse protocol."
  [request]
  (let [base-url (http/base-url request)
        config-path (path/new-path (:metadata-path request) "config.json")]
    (if (.exists (io/file config-path))
      (-> (slurp config-path)
          (ring/response)
          (ring/content-type "application/json"))
      (let [config {:dl (str base-url "/api/v1/crates")
                   :api base-url
                   :auth-required false}]
        (-> (json/generate-string config)
            (ring/response)
            (ring/content-type "application/json"))))))

(defn get-crate-index
  "Return the index file for a crate by its name."
  [request crate-name]
  (if-let [db (:database request)]
    (try
      (if-let [crate (crate-db/by-name db crate-name)]
        (let [versions (crate-db/get-crate-and-versions db crate-name)
              index-content (string/join "\n" (map json/generate-string versions))]
          (-> (ring/response index-content)
              (ring/content-type "application/json")
              ;; Add caching headers
              (ring/header "Cache-Control" "public, max-age=3600")
              (ring/header "ETag" (str "W/\"" (hash index-content) "\""))))
        (ring/not-found {:status "not_found"
                         :error (str "Crate '" crate-name "' not found")}))
      (catch Exception e
        (log/error e "Error getting crate index for" crate-name)
        (ring/not-found {:status "not_found"
                         :error (str "Crate '" crate-name "' not found")})))
    (do
      (log/error "Database connection is missing in the request for crate-index" crate-name)
      (ring/not-found {:status "error"
                        :error "Internal server error: database connection missing"}))))

(defn- extract-crate-name
  "Extract crate name from request path and directory structure."
  [request pattern]
  (let [uri (:uri request)
        match (re-find pattern uri)]
    (when match
      (second match))))

(defn get-index-one-char
  "Handle requests for crates with one character name."
  [request]
  (if-let [db (:database request)]
    (let [uri (:uri request)
          pattern #"/1/([a-z0-9])$"
          match (re-find pattern uri)]
      (if (and match (>= (count match) 2))
        (get-crate-index request (nth match 1))
        (ring/not-found {:status "not_found"
                          :error "Invalid path for one character crate name"})))
    (do
      (log/error "Database connection is missing in the request for get-index-one-char")
      (ring/not-found {:status "error"
                        :error "Internal server error: database connection missing"}))))

(defn get-index-two-char
  "Handle requests for crates with two characters name."
  [request]
  (if-let [db (:database request)]
    (let [uri (:uri request)
          pattern #"/2/([a-z0-9]{2})$"
          match (re-find pattern uri)]
      (if (and match (>= (count match) 2))
        (get-crate-index request (nth match 1))
        (ring/not-found {:status "not_found"
                          :error "Invalid path for two characters crate name"})))
    (do
      (log/error "Database connection is missing in the request for get-index-two-char")
      (ring/not-found {:status "error"
                        :error "Internal server error: database connection missing"}))))

(defn get-index-three-char
  "Handle requests for crates with three characters name."
  [request]
  (if-let [db (:database request)]
    (let [uri (:uri request)
          pattern #"/3/([a-z0-9])/([a-z0-9]{3})$"
          match (re-find pattern uri)]
      (if (and match (>= (count match) 3))
        (get-crate-index request (nth match 2))
        (ring/not-found {:status "not_found"
                          :error "Invalid path for three characters crate name"})))
    (do
      (log/error "Database connection is missing in the request for get-index-three-char")
      (ring/not-found {:status "error"
                        :error "Internal server error: database connection missing"}))))

(defn get-index-crate
  "Handle requests for crates with four or more characters name."
  [request]
  (if-let [db (:database request)]
    (let [uri (:uri request)
          pattern #"/([a-z0-9]{2})/([a-z0-9]{2})/([a-z0-9_-]+)$"
          match (re-find pattern uri)]
      (if (and match (>= (count match) 4))
        (get-crate-index request (nth match 3))
        (ring/not-found {:status "not_found"
                          :error "Invalid path for crate name"})))
    (do
      (log/error "Database connection is missing in the request for get-index-crate")
      (ring/not-found {:status "error"
                        :error "Internal server error: database connection missing"}))))