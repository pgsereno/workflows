// Replaces the comment the Vercel Git integration used to post. Sticky via a
// hidden marker so re-runs update one comment instead of stacking.
module.exports = async ({ github, context }) => {
	const { PREVIEW_URL: url, INSPECT_URL: inspect, STATE: state = "UNKNOWN" } = process.env;
	const marker = "<!-- vercel-preview-deployment -->";
	const sha = context.payload.pull_request.head.sha.slice(0, 7);
	const updated = new Date().toISOString().replace("T", " ").slice(0, 16) + " UTC";
	const status = state === "READY" ? "✅ Ready" : `❌ ${state}`;
	const preview = state === "READY" ? `[Visit Preview](${url})` : "—";
	const inspectCell = inspect ? `[Inspect](${inspect})` : "—";
	const body = [
		marker,
		"### ▲ Vercel preview deploy",
		"",
		"| Project | Status | Preview | Inspect | Commit | Updated |",
		"|---|---|---|---|---|---|",
		`| \`${context.repo.repo}\` | ${status} | ${preview} | ${inspectCell} | \`${sha}\` | ${updated} |`,
	].join("\n");

	const { owner, repo } = context.repo;
	const issue_number = context.issue.number;
	const { data: comments } = await github.rest.issues.listComments({ owner, repo, issue_number });
	const existing = comments.find((c) => c.body?.includes(marker));
	if (existing) {
		await github.rest.issues.updateComment({ owner, repo, comment_id: existing.id, body });
	} else {
		await github.rest.issues.createComment({ owner, repo, issue_number, body });
	}
};
