# Himalaya Message Composition with MML

Himalaya uses MML (MIME Meta Language), a simple XML-like syntax that compiles to MIME messages.

## Basic message

Headers, blank line, body:

```text
From: sender@example.com
To: recipient@example.com
Subject: Hello World

This is the message body.
```

Common headers: `From`, `To`, `Cc`, `Bcc`, `Subject`, `Reply-To`, `In-Reply-To`.

Address examples:

```text
To: user@example.com
To: John Doe <john@example.com>
To: "John Doe" <john@example.com>
To: user1@example.com, user2@example.com, "Jane" <jane@example.com>
```

## Plain text

```text
From: alice@localhost
To: bob@localhost
Subject: Plain Text Example

Hello, this is a plain text email.

Best,
Alice
```

## Multipart alternative

```text
From: alice@localhost
To: bob@localhost
Subject: Multipart Example

<#multipart type=alternative>
This is the plain text version.
<#part type=text/html>
<html><body><h1>This is the HTML version</h1></body></html>
<#/multipart>
```

## Attachments

```text
From: alice@localhost
To: bob@localhost
Subject: With Attachment

Here is the document you requested.

<#part filename=/path/to/document.pdf><#/part>
```

Custom attachment name:

```text
<#part filename=/path/to/file.pdf name=report.pdf><#/part>
```

Multiple attachments:

```text
<#part filename=/path/to/doc1.pdf><#/part>
<#part filename=/path/to/doc2.pdf><#/part>
```

## Inline images

```text
From: alice@localhost
To: bob@localhost
Subject: Inline Image

<#multipart type=related>
<#part type=text/html>
<html><body>
<p>Check out this image:</p>
<img src="cid:image1">
</body></html>
<#part disposition=inline id=image1 filename=/path/to/image.png><#/part>
<#/multipart>
```

## Mixed text plus attachments

```text
From: alice@localhost
To: bob@localhost
Subject: Mixed Content

<#multipart type=mixed>
<#part type=text/plain>
Please find the attached files.

Best,
Alice
<#part filename=/path/to/file1.pdf><#/part>
<#part filename=/path/to/file2.zip><#/part>
<#/multipart>
```

## CLI composition

Interactive editor:

```bash
himalaya message write
```

Reply:

```bash
himalaya message reply 42
himalaya message reply 42 --all
```

Forward:

```bash
himalaya message forward 42
```

Send from stdin, preferred for Hermes automation:

```bash
cat message.txt | himalaya template send
```

Prefill headers:

```bash
himalaya message write \
  -H "To:recipient@example.com" \
  -H "Subject:Quick Message" \
  "Message body here"
```

Use `himalaya message export --full` to inspect raw MIME.
