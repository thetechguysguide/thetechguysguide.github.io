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
