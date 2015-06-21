curl -X POST \
	-H 'X-Hub-Signature: sha1=fa9bbd6211de3dc96cde2800fa80fc0d9a9f5fb8' \
	-H 'X-Github-Event: issues' -d @data/closed_issue.json localhost:3000/event
