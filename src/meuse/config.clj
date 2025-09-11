(ns meuse.config
  "Load the project configuration."
  (:require [exoscale.cloak :as cloak]
            [exoscale.ex :as ex]
            [meuse.log :as log]
            [meuse.spec :as spec]
            [environ.core :refer [env]]
            [mount.core :refer [defstate]]
            [unilog.config :refer [start-logging!]]
            [yummy.config :as yummy]))

(defn stop!
  "Stop the application."
  []
  (System/exit 1))

(defn- convert-string-to-appropriate-type
       "Convert string values to appropriate types based on their content.
        This is needed because environment variables loaded through !envvar
        are always treated as strings, but some values need to be numbers or booleans."
       [value]
       (cond
         ;; If it's not a string, return as is
         (not (string? value)) value

         ;; Convert "true" and "false" to boolean values
         (= "true" value) true
         (= "false" value) false

         ;; Try to convert to integer if it matches a number pattern
         (re-matches #"^\d+$" value) (Integer/parseInt value)

         ;; Otherwise keep as string
         :else value))

(defn- convert-config-types
       "Recursively traverse the configuration map and convert values to appropriate types."
       [config]
       (cond
         ;; If it's a map, process each value recursively
         (map? config) (into {} (map (fn [[k v]] [k (convert-config-types v)]) config))

         ;; If it's a collection (but not a map), process each item recursively
         (and (coll? config) (not (map? config))) (into (empty config) (map convert-config-types config))

         ;; For leaf values, convert to appropriate type
         :else (convert-string-to-appropriate-type config)))

(defn load-config
  "Takes a path and loads the configuration."
  [path]
      (let [raw-config (yummy/load-config
                         {:program-name :meuse
                          :path         path
                          :spec         nil                 ;; Disable validation here, we'll do it after type conversion
                          :die-fn
                          (fn [e msg]
                              (let [error-msg (str "fail to load config: "
                                                   msg
                                                   "\n"
                                                   "config path = "
                                                   path)]
                                   (log/error {} e error-msg)
                                   (stop!)))})
            ;; Convert string values to appropriate types
            config (convert-config-types raw-config)]
           ;; Validate against spec after type conversion
           (try
             (yummy/validate config ::spec/config)
             (catch Exception e
               (let [error-msg (str "fail to load config: validation\n"
                                    "config path = "
                                    path)]
                    (log/error {} e error-msg)
                    (stop!))))
    (when-let [front-secret (get-in config [:frontend :secret])]
      (when (< (count (cloak/unmask front-secret)) spec/frontend-secret-min-size)
        (throw (ex/ex-incorrect (format "The frontend secret is too small (minimum size is %d"
                                        spec/frontend-secret-min-size)))))
    (start-logging! (:logging config))
    (log/info {} "config loaded, logger started !")
    config))

(defstate config
  :start (load-config (env :meuse-configuration)))
