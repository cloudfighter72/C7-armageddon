AWS
-----

Security Groups:

1. Build a Security Group (Ports 22 and 80)
- Name: wolfpack-wednesday
- Description: wolfpack-wednesday
- VPC: Leave default

Inbound Rules
- Add Rule
- Type: SSH | Protocol: TCP | Port Range: 22 | Source Type: Anywhere IPv4 | Source: (Default 0.0.0.0) | Description: SSH
- Add Rule
- Type: HTTP | Protocol: TCP | Port Range: 80 | Source Type: Anywhere IPv4 | Source: (Default 0.0.0.0) | Description: HTTP

Outbound Rules
- SKIP OUTBOUND RULES!!!! GO AROUND THEM OR SUFFER THE WRATH OF CHEWBACCA!!!!

Tags
- Key: Name
- Value: wolfpack-wednesday


2. Build an EC2 Instance (Amazon Linux based 2023)
- Click the orange button "Launch instance"
- Name: wolfpack-wednesday

Applications and OS Images (Amazon Machine Image)
- Click the "Quick Start" tab
- Ensure "Amazon Linux" icon is selected
- Amazon Machine Image: "Amazon Linux 2023 kernel-6.1 AMI" (default)
Description: Leave as default
- Instance Type: t3.micro

Key pair (login)
- Click "Create new key pair"
- Key pair name: wolfpack-wednesday
- Key pair type: RSA (leave as default)
- Private key file format: .pem (leave as default)
- Click orange button (Create key pair)
- Save your key pair in your DOWNLOADS folder on your computer
- NOTE: Key pair name is now populated with "wolfpack-Wednesday"

Network Settings:
Network: leave as default
Subnet: leave as default
Auto-assign public IP: should be defaulted as "Enable"

Firewall Security groups: 
- Click "Select existing security group"
- Scroll down and click on "wolfpack-wednesday"

Configure storage: leave as default

Advanced details:
- Scroll all the way down to user data (optional)
- (SKIP EVERYTHING BEFORE IT)
- Access the MookieWAF EC2script via GitHub: https://github.com/MookieWAF/bmc4/blob/main/ec2scrpit
- Click the two boxes in the top right corner labeled as "Copy Raw File"
- Look for the pop up box that indicated it was "Copied"
- Go back to your EC2 Instance user data block and paste your script (Ensure the entire script was pasted correctly).
- PRAY TO CHEWBACCA BEFORE YOU LAUNCH INSTANCE!!!
- Click the orange button and Launch Instance at the bottom of the page.

Copy and Paste Public DNS
- In the green banner click the Instance ID number (labeled as i-xxxxxxxxxx)
- On the right hand side click the two boxes underneath the "Public DNS" section. Ensure it says "Public DNS copied"
- Open a new tab on your web browser and type "http://", then copy the public DNS and press ENTER.
- Verify your AWS Instance Details script loads properly. If yes, proceed on.

SSH into EC2 Instance as it's running
- Go back to your Instance summary page (the same page you copied and pasted your Public DNS)
- Click the "Connect" button at the top of the page.
- On the next page leave everything as default and click the orange "Connect" button at the bottom right of the page.
- Look for the Black Bird and the "Amazon Linux 2023" logo at the top.

9. Modify EC2 Script and refresh the WebServer page

On the command line type the following commands.

```sh
sudo vim /var/www/html/index.html
```
- Press the letter "i" on your keyboard (lowercase i, NOT UPPERCASE I). This will change your script to INSERT MODE at the bottom left of the screen.
- Using your keyboard arrows, move up, down, left, or right in the script to modify your script.

- Check the line "Samurai Katana" and change to "Wolfpack Wednesday"
- Remove the entire line "# insert an image or GIF"
- Paste updated image file one the next line after `img src=<image-file-here`

Press the "Esc" button
Type the command :wq and Press Enter

10. Ping IP address 8.8.8.8 (Google DNS) to show web connectivity.

```bash
ping 8.8.8.8
```

- Verify the connectivity is running to the internet.
- Press either "CTRL+C" or "CTRL+Z" to stop the ping.

11. Teardown

- Go to your EC2 Instance. Go to Action and click "Terminate Instance.
- Go to your Security Group, click the Action button at the top and click "Delete Security Group"
- Praise Chewbacca and Get this Money

CREATE NEW REPO ON THE COMMAND LINE

echo "# cloudfighter72" >> README.md
git init
git add README.nmd
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/cloudfighter72/wolfpackHW.git
git push -u origin main

PUSH AN EXISTING REPO FROM COMMAND LINE

git remote add origin https://github.com/cloudfighter72/wolfpackHW.git
git branch -M main
git push -u origin main
