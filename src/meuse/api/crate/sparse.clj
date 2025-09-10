(ns meuse.api.crate.sparse
  "Implements the Cargo sparse registry protocol."
  (:require [meuse.crate :as crate]
            [meuse.db.public.crate :as public-crate]
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
  (let [db (:database request)
        versions (public-crate/get-crate-versions db {:name crate-name})]
    (if (seq versions)
      (let [index-content (string/join "\n" (map json/generate-string versions))]
        (-> (ring/response index-content)
            (ring/content-type "application/json")
            ;; Add caching headers
            (ring/header "Cache-Control" "public, max-age=3600")
            (ring/header "ETag" (str "W/\"" (hash index-content) "\"")))
        (ring/not-found {:status "not_found"
                         :error (str "Crate '" crate-name "' not found")}))))

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
  (let [crate-name (extract-crate-name request #"/1/([a-z0-9])$")]
    (if crate-name
      (get-crate-index request crate-name)
      (ring/not-found {:status "not_found"
                        :error "Invalid path for one character crate name"}))))

(defn get-index-two-char
  "Handle requests for crates with two characters name."
  [request]
  (let [crate-name (extract-crate-name request #"/2/([a-z0-9]{2})$")]
    (if crate-name
      (get-crate-index request crate-name)
      (ring/not-found {:status "not_found"
                        :error "Invalid path for two characters crate name"}))))

(defn get-index-three-char
  "Handle requests for crates with three characters name."
  [request]
  (let [crate-name (extract-crate-name request #"/3/([a-z0-9])/([a-z0-9]{3})$")]
    (if crate-name
      (get-crate-index request crate-name)
      (ring/not-found {:status "not_found"
                        :error "Invalid path for three characters crate name"}))))

(defn get-index-crate
  "Handle requests for crates with four or more characters name."
  [request]
  (let [crate-name (extract-crate-name request #"/([a-z0-9]{2})/([a-z0-9]{2})/([a-z0-9_-]+)$")]
    (if crate-name
      (get-crate-index request crate-name)
      (ring/not-found {:status "not_found"
                        :error "Invalid path for crate name"}))))