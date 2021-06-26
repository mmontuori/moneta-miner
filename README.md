Moneta-miner (https://moneta.misas.us)
===


What is Moneta-miner?
---
**Moneta-miner** is a project which helps bootstrapping mining Moneta digital currency.

**NOTE: This project only helps to get started. It is preferred that you understand how Bitcoin derivate currencies work. There are additional steps not listed here that you should perform to finalize your installation. Things like securing the wallets and backups should be considered.**


Requirements
---
* Docker container system
* Linux
* GIT


Getting started mining Moneta
---
Execute the following steps to start mining:
* Get a server(s) with sufficient CPU/GPU power to executes the hashes. This power will change overtime as the Moneta network grows
* Create a user on the system. For simplicity call it "moneta"
* Give the user authority to run docker by adding the "moneta" user to the "docker" group
* Make sure docker.io is installed and running on the system
* Login as "moneta" and clone this repository to the HOME directory
* Change directory to **moneta-miner**
* Copy the sample environment file moneta.env.sample to moneta.env
* Edit the environment file moneta.env to setup the Moneta environment
* Execute **./miner.sh prepare**. This command will prepare the docker images, clone and compile Moneta
* Execute **./miner.sh start** to start the mining process
* Execute **./miner.sh start** to stop the mining process

For more information, as well as an immediately useable, binary version of
the Moneta Core software, see [https://moneta.misas.us](https://moneta.misas.us).


Who is behind Moneta-miner?
---------------------
[Michael Montuori](https://github.com/mmontuori) is the main developer behind Moneta. Michael has over 30 years of experience. His public credentials are listed in his [public resume](https://registry.jsonresume.org/mmontuori).

Other developers, contributors, and testers:
* Pino Caci


License
-------
Moneta Core is released under the terms of the MIT license. See [COPYING](COPYING) for more
information or see https://opensource.org/licenses/MIT.
