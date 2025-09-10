(ns meuse.api.crate.http
  (:require [meuse.api.default :as default]
            [meuse.api.crate :as mac]))

(def skip-auth
  "Skip token auth for these calls."
  #{:search :download :config :index-one-char :index-two-char :index-three-char :index-crate})

(def crates-routes
  {#"/new/?" {:put ::new}
   #"/config\.json" {:get ::config}
   #"/1/[a-z0-9]" {:get ::index-one-char}
   #"/2/[a-z0-9]{2}" {:get ::index-two-char}
   #"/3/[a-z0-9]/[a-z0-9]{3}" {:get ::index-three-char}
   #"/[a-z0-9]{2}/[a-z0-9]{2}/[a-z0-9_-]+" {:get ::index-crate}
   #"/"? {:get ::search}
   ["/" mac/crate-name-path #"/owners/?"] {:put ::add-owner}
   ["/" mac/crate-name-path #"/owners/?"] {:delete ::remove-owner}
   ["/" mac/crate-name-path #"/owners/?"] {:get ::list-owners}
   ["/" mac/crate-name-path "/" mac/crate-version-path "/yank"] {:delete ::yank}
   ["/" mac/crate-name-path "/" mac/crate-version-path "/unyank"] {:put ::unyank}
   ["/" mac/crate-name-path "/" mac/crate-version-path "/download"] {:get ::download}
   #"/andouillette" ::andouillette})

(defmulti crates-api!
  "Handle crates API calls"
  :action)

(defmethod crates-api! :config
  [request]
  (require '[meuse.api.crate.sparse :as sparse])
  ((resolve 'meuse.api.crate.sparse/get-config) request))

(defmethod crates-api! :index-one-char
  [request]
  (require '[meuse.api.crate.sparse :as sparse])
  ((resolve 'meuse.api.crate.sparse/get-index-one-char) request))

(defmethod crates-api! :index-two-char
  [request]
  (require '[meuse.api.crate.sparse :as sparse])
  ((resolve 'meuse.api.crate.sparse/get-index-two-char) request))

(defmethod crates-api! :index-three-char
  [request]
  (require '[meuse.api.crate.sparse :as sparse])
  ((resolve 'meuse.api.crate.sparse/get-index-three-char) request))

(defmethod crates-api! :index-crate
  [request]
  (require '[meuse.api.crate.sparse :as sparse])
  ((resolve 'meuse.api.crate.sparse/get-index-crate) request))

(defmethod crates-api! :default
  [request]
  (default/not-found request))
