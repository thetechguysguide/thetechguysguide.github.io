Why Enable the Admin Socket
You enable the admin socket if you want to monitor or control HAProxy while it's running — like checking live stats, temporarily disabling a backend server, or integrating with monitoring tools.

Why Disable the Admin Socket
You disable it if you don’t need real-time control or want to keep things simple and secure — especially if you’re not using tools that connect to the socket or you’re just using the web stats page.

Enabling requires more configuration, just as a fyi

Steps to Disable the Admin Socket

1. *** Edit HAProxy Config

	Open the configuration file:

	sudo nano /etc/haproxy/haproxy.cfg

2. *** Comment Out or Remove This Line in the global Section

	# stats socket /run/haproxy/admin.sock mode 660 level admin

3. *** Save and Exit

	Restart HAProxy:

	sudo systemctl restart haproxy

	Verify It's Gone
	Check that HAProxy no longer tries to bind the socket:

	sudo journalctl -u haproxy | grep socket

	You should not see:

	cannot bind UNIX socket /run/haproxy/admin.sock

Enabling the Admin Socket

1. *** Restore the Config Line
	Edit your config if you commented it out:

	sudo nano /etc/haproxy/haproxy.cfg

	Make sure this is present in the global section:

	stats socket /run/haproxy/admin.sock mode 660 level admin

	Save and exit.
2. *** Make Sure /run/haproxy Exists at Boot

	We must ensure the subdirectory gets created every time the system boots.
	Create the tmpfiles rule:

	sudo nano /etc/tmpfiles.d/haproxy.conf

	Add this line:

	d /run/haproxy 0755 haproxy haproxy

	Run:
	
	sudo systemd-tmpfiles --create

3. *** Apply SELinux Context (if using SELinux)

	sudo semanage fcontext -a -t haproxy_var_run_t "/run/haproxy(/.*)?"
	sudo restorecon -Rv /run/haproxy

4. *** Restart HAProxy

	sudo systemctl restart haproxy

	Verify it's running:

	sudo systemctl status haproxy

5. *** Test the Admin Socket

	Install socat if not already installed:

	sudo dnf install socat -y

	Run a quick test:

	echo "show info" | sudo socat unix-connect:/run/haproxy/admin.sock stdio

	You should see output like:

		Name: HAProxy
		Version: 2.4.22

Hope this helps
