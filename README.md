Overview
========

This is a refactor of Travis F. Smith's `SweetSecurity` repository for building a defensible Raspberry Pi. User should have sudo privileges to install software and situate configuration files on the filesystem.

Improvements
============

- Upgraded versions of Bro and ELK stack to current
- Changed from hardcoded `pi` user to configurable working directory `INSTALL_DIR`
- Reduced privileges where possible to run commands unprivileged as the user
- Silenced echo of Critical Stack API key and email password with `read -s`
- Moved logical groupings of code into individual functions
- Added integrity verification of downloads where possible: Bro (signature), ELK (SHA-1)
- Submitted ticket to Critical Stack to add their deb into their repository with signing key and signature
- Ported deprecated init code (`update-rc.d`, `service`, etc) to systemd current equivalent with `systemctl`
- Created `start_kibana` and `stop_kibana` scripts for use with systemd invokation
- Replaced deprecated `init.d/kibana` with current `system/kibana.service`
- Exported `intel.criticalstack.com` certificate for use with Critical Stack deb download
- Commented out code for blacklisting Tor exit nodes. Use Signal. Use Tor.

Issues Addressed
================

A number of issues and pull requests are sitting `Open` on the original repository so some of the issues were addressed.

- Optimized and fixed `logstash.conf` user value substitution (https://github.com/TravisFSmith/SweetSecurity/issues/10)
- Removed `networkDiscovery.py` and `SweetSecurityDB.py` as they were not utilized (https://github.com/TravisFSmith/SweetSecurity/issues/11)
- Condensed directory creation with `mkdir -p` (https://github.com/TravisFSmith/SweetSecurity/pull/8/commits/19dc0f8d1c5b579a8edec971310559823e9c1f91)
- Added variables for software versions (https://github.com/TravisFSmith/SweetSecurity/pull/8/commits/4135d8932d1cf77b49bafce9d876bdeeecd3305c https://github.com/TravisFSmith/SweetSecurity/pull/8/commits/7830f7cd629e573dd777a2d031fe3041ec972561 https://github.com/TravisFSmith/SweetSecurity/pull/8/commits/593266c4b05de56b4a435e3d038d7c5f485ce386 https://github.com/TravisFSmith/SweetSecurity/pull/8/commits/6b1aa3723419a69d78700c5a0f8cb95b3aec44a8)
- Added `git-core` and `default-jdk` to dependencies (https://github.com/TravisFSmith/SweetSecurity/pull/9/commits/5ac54197eaecf50b781f7cc0d4ffe725e8a102ed)
