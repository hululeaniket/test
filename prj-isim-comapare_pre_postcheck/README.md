## Role - rol-capg-prepostchecks

Role used to compare prechecks and postcheck csv files.

## Requirements

In files directory or while Excuting Playbook , need 2 csv files named: post_checks.csv and pre_checks.csv.

## Role Variables

    Variables in vars/main.yml:
      output_path: roles/rol-capg-prepostchecks/files/output.csv

## Dependencies

none.

## Playbook Excution 

ansible-playbook  playbook.yml  --extra-vars "prechecks_path=Pre-checks.csv postchecks_path=Post-check.csv "

## License

CAPGEMINI CIS

## Author Information

Create POD Automation.