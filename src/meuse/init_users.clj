(ns meuse.init-users
  "Functions to initialize users from configuration"
  (:require [meuse.auth.password :as password]
            [meuse.config :refer [config]]
            [meuse.db.public.user :as user-db]
            [meuse.log :as log]
            [mount.core :refer [defstate]]))

(defn- create-user-if-not-exists
  "Create a user if it doesn't already exist in the database"
  [user-db user-config]
  (let [username (:name user-config)]
    (if (user-db/by-name user-db username)
      (log/info {} "User already exists, skipping:" username)
      (try
        (log/info {} "Creating initial user:" username)
        (user-db/create user-db user-config)
        (log/info {} "Successfully created user:" username)
        (catch Exception e
          (log/error {} e "Failed to create initial user:" username))))))

(defn initialize-users
  "Initialize users from configuration"
  []
  (when-let [init-users (get-in config [:init-users :users])]
    (log/info {} "Initializing users from configuration")
    (doseq [user init-users]
      (create-user-if-not-exists user-db/user-db user))))

;; Define a mount component that runs after database is initialized
(defstate init-users
  :start (do
           (log/debug {} "Starting user initialization from config")
           (initialize-users)
           (log/debug {} "Completed user initialization from config")
           true))
