# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# A hand-written ACS rule for the custom-rego More lab. Instead of denying the
# whole response when it contains a live secret, this TRANSFORMS the output by
# redacting the secret in place, so the useful part of the answer still reaches
# the user. Test it with:
#
#   echo '{"intervention_point":"output","policy_target":{"value":"key sk-live-ABC123 here"}}' \
#     | opa eval -I -d src/policy/examples 'data.workshop.custom.output_verdict' -f pretty

package workshop.custom

import rego.v1

default output_verdict := {"decision": "allow"}

output_verdict := {
	"decision": "transform",
	"transform": {
		"path": "$.output",
		"value": regex.replace(input.policy_target.value, `sk-live-[A-Za-z0-9]+`, "sk-live-REDACTED"),
	},
} if {
	input.intervention_point == "output"
	regex.match(`sk-live-[A-Za-z0-9]+`, input.policy_target.value)
}
