(ns meuse.interceptor.db
  "Database interceptor"
  (:require [meuse.db :refer [database]]
            [meuse.log :as log]))

(def database-interceptor
  {:name ::database
   :enter (fn [{:keys [request] :as ctx}]
            (log/debug {} "Adding database connection to request")
            (assoc ctx :request (assoc request :database database)))})