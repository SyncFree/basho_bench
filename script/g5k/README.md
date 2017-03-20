Take a look at /script/g5k/configuration.sh

1. Connect to grid5000, in any site you want (`nancy`, `sophia`, etc)
2. Generate a key pair (without password) for the experiments.
3. Clone the basho_bench repo with these scripts to your home directory
4. Put the paths to the key pair in the configuration file (`PRKFILE` and `PBKFILE`)
5. Clone the antidote image from `/home/bderegil/public/antidote-images/latest/*`:

  ```
  cp /home/bderegil/public/antidote-images/latest/* <your-image-path>
  ```

6. Put your `antidote.env` file path into `configuration.sh` -> `K3_IMAGE`
7. Pick the set of g5k sites to run the benchmark (`configuration.sh` -> `SITES`)
8. Fill in the details in the configuration file
9. Run the configuration  (The directory you execute from doesn't matter):

  ```
  ./basho_bench/script/g5k/main.sh
  ```
