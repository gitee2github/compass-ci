
# send mail

## purpose

The service is used to send mails with formatted mail data
- send intranet mail
- send internet mail

## send mail port
- send intranet mail: 11311
- send internet mail: 49000

## send mail host
- host the service running on

## data format
- send_mail_yaml
  - data format
      data='{
      "subject": "email subject",
      "to": "email_to_addr",
      "body": "email message"
      }'
    or
      data="
      subject: email subject
      to: email_to_addr
      body: email message
      "

- send_mail_text
  - data format
      data="
      To: email_to_addr
      Subject: email_subject

      mail_msg_line1
      mail_msg_line2
      ...
      "

## usage:
- send_mail_yaml
    curl -XPOST '#{SEND_MAIL_HOST}:#{SEND_MAIL_PORT}/send_mail_yaml' -d "$data"
- send_mail_text
    curl -XPOST '#{SEND_MAIL_HOST}:#{SEND_MAIL_PORT}/send_mail_text' -d "$data"

## example

	data = "
	To: test_email@163.com
	Subject: test mail 10
 
	test msg 1010
	"

	%x(curl -XPOST 'localhost:49000/send_mail_text' -d "#{data}")