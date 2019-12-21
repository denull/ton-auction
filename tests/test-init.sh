../init.fif 0 EQAQ83rO1RKSt52-egGQ7Qz8EINnZtCk3H7tyFlumlNGoFmw auction
read -p "Send 1 Gram to the non-bouncable address above and press [Enter] to continue"
../../build/lite-client/lite-client  -C ../../ton-lite-client-test1.config.json -c"sendfile auction-init-query.boc"