(ns meuse.init-users
  "Functions to create initial users from configuration"
  (:require [meuse.auth.password :as password]
            [meuse.db.actions.user :as user-actions]
            [meuse.log :as log]
            [next.jdbc :as jdbc]))

(defn create-user!
  "Create a single user from configuration."
  [database user-config]
  (let [user-name (:name user-config)
        role-name (:role user-config)
        description (:description user-config)
        password (:password user-config)
        active (if (nil? (:active user-config)) true (:active user-config))]
    (try
      (log/info {} (format "Creating initial user %s with role %s" user-name role-name))
      (user-actions/create database {:name user-name
                                     :description description
                                     :password password
                                     :role role-name
                                     :active active})
      (log/info {} (format "Successfully created user %s" user-name))
      (catch Exception e
        (log/error {} e (format "Failed to create initial user %s: %s" 
                                user-name 
                                (.getMessage e)))))))

(defn create-initial-users!
  "Create initial users from configuration."
  [database config]
  (when-let [initial-users (:initial-users config)]
    (log/info {} (format "Creating %d initial users from configuration" (count initial-users)))
    (doseq [user-config initial-users]
      (create-user! database user-config))
    (log/info {} "Completed initial users creation")))