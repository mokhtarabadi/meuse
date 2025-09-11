(ns meuse.init-users-test
  (:require [meuse.init-users :refer :all]
            [meuse.db.public.user :as user-db]
            [clojure.test :refer :all]
            [spy.core :as spy]
            [spy.assert :as assert]))

(deftest initialize-users-test
  (testing "initializes users from config"
    ;; Test with the create function mocked to verify call counts
    (with-redefs [meuse.config/config {:init-users {:users [{:name "user1" :password "pw1" :description "desc1" :role "admin"}
                                                            {:name "user2" :password "pw2" :description "desc2" :role "tech"}]}}
                  user-db/by-name (constantly nil)
                  user-db/create (spy/spy)]
      (initialize-users)
      (assert/called-n-times? user-db/create 2)))

  (testing "does nothing when no init-users in config"
    (with-redefs [meuse.config/config {}
                  user-db/create (spy/spy)]
      (initialize-users)
      (assert/not-called? user-db/create)))

  (testing "skips existing users"
    (with-redefs [meuse.config/config {:init-users {:users [{:name "existing1" :password "pw1" :description "desc1" :role "admin"}
                                                            {:name "new1" :password "pw2" :description "desc2" :role "tech"}]}}
                  user-db/by-name (fn [_ username]
                                    (when (= username "existing1")
                                      {:users/name "existing1"}))
                  user-db/create (spy/spy)]
      (initialize-users)
      (assert/called-n-times? user-db/create 1))))
