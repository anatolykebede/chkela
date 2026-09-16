import {
  Callout,
  Card,
  CardBody,
  CardHeader,
  Divider,
  Grid,
  H1,
  H2,
  H3,
  Pill,
  Row,
  Stack,
  Stat,
  Table,
  Text,
} from "cursor/canvas";

export default function PathProductionAudit() {
  return (
    <Stack gap={24}>
      <Stack gap={8}>
        <H1>The Path: production audit</H1>
        <Text tone="secondary">
          Grade-scoped Path (G9–11 own grade, G12 sees 9–12), CMS gates, progress sync,
          Answer waves. Verdict for shipping as a multi-grade product.
        </Text>
      </Stack>

      <Grid columns={4} gap={16}>
        <Stat value="No" label="Ship multi-grade?" tone="danger" />
        <Stat value="Soft" label="G9 Bio beta?" tone="warning" />
        <Stat value="3" label="Blockers" tone="danger" />
        <Stat value="8" label="High risks" tone="warning" />
      </Grid>

      <Callout tone="danger" title="Verdict">
        Not production-ready as a full Path product. Grade filtering and local combat work.
        Progress API is insecure, G10/G11 maps are empty, and sync cannot restore a wiped
        device. Treat as Grade 9 Biology beta only, or fix blockers first.
      </Callout>

      <Divider />

      <H2>What works</H2>
      <Grid columns={2} gap={16}>
        <Card>
          <CardHeader trailing={<Pill tone="success" size="sm">Solid</Pill>}>
            Grade visibility
          </CardHeader>
          <CardBody>
            <Text>
              G9–11 see only their gradeId. G12 sees grade-9…12. Catalog filters drafts and
              sorts by grade then order. Admin grade filter matches.
            </Text>
          </CardBody>
        </Card>
        <Card>
          <CardHeader trailing={<Pill tone="success" size="sm">Solid</Pill>}>
            Local loop
          </CardHeader>
          <CardBody>
            <Text>
              Energy, stars, streak, weak skills, XP wallet on device. Combat UX (Strike,
              Blitz, Link, Sequence, Answer) is playable offline via assets fallback.
            </Text>
          </CardBody>
        </Card>
        <Card>
          <CardHeader trailing={<Pill tone="success" size="sm">Solid</Pill>}>
            CMS dual-write
          </CardHeader>
          <CardBody>
            <Text>
              shared/path + assets/path stay in sync via Vite plugin. App can load Path from
              LAN, CONTENT_API_BASE, then bundled JSON.
            </Text>
          </CardBody>
        </Card>
        <Card>
          <CardHeader trailing={<Pill tone="warning" size="sm">Partial</Pill>}>
            Progress POST
          </CardHeader>
          <CardBody>
            <Text>
              After each attempt, phone + full Path state POSTs to /api/path/progress. Failures
              are silent. No pull on launch.
            </Text>
          </CardBody>
        </Card>
      </Grid>

      <Divider />

      <H2>Blockers (must fix before prod)</H2>
      <Table
        headers={["ID", "Issue", "Impact", "Fix"]}
        rows={[
          [
            "B1",
            "Progress API has no auth",
            "Anyone can POST any phone or GET full student dump",
            "Session/token auth; drop public GET or admin-only",
          ],
          [
            "B2",
            "G10/G11 Path empty",
            "Map shows no gates; daily still Bio-flavored",
            "Seed content per grade or honest empty + CTA",
          ],
          [
            "B3",
            "Sync is push-only file DB",
            "Reinstall loses Path; no merge; race on concurrent writes",
            "GET restore + merge; real DB; write lock",
          ],
        ]}
        rowTone={["danger", "danger", "danger"]}
      />

      <H2>High risks</H2>
      <Table
        headers={["ID", "Issue", "Why it hurts"]}
        rows={[
          [
            "H1",
            "Release still hits LAN Vite URL",
            "Phones on cellular fail slow before assets; wrong host in field",
          ],
          [
            "H2",
            "Daily Challenge still Bio hardcoded",
            "Grade filter hides wrong gates but daily text/tags stay Bio",
          ],
          [
            "H3",
            "G12 unlocks one mega chain",
            "Must clear G9…G11 before G12; long grind, not 4 Paths",
          ],
          [
            "H4",
            "Star keys = level.id only",
            "G9+G12 both on map: duplicate ids would clash progress",
          ],
          [
            "H5",
            "Answer grading is soft normalize",
            "Math fractions/units fail; Bio synonyms fail",
          ],
          [
            "H6",
            "Energy spent on Enter, not finish",
            "Quit after pay = lost energy; feels punitive",
          ],
          [
            "H7",
            "Play route skips lock check",
            "Deep link /the-path/level/:id can bypass map lock",
          ],
          [
            "H8",
            "Phone as account key",
            "No login → no server progress; shared device overwrites",
          ],
        ]}
        rowTone={[
          "warning",
          "warning",
          "warning",
          "warning",
          "warning",
          "warning",
          "warning",
          "warning",
        ]}
      />

      <Divider />

      <H2>Grade content reality</H2>
      <Table
        headers={["Grade", "Path gates in CMS", "Student experience"]}
        rows={[
          ["9", "Yes (Bio chapter 1–2 style)", "Playable end-to-end"],
          ["10", "None", "Empty map; daily still works but Bio-biased"],
          ["11", "None", "Same as G10"],
          ["12", "Sees G9 content only today", "Full G9 Path + empty higher grades"],
        ]}
        rowTone={["success", "danger", "danger", "warning"]}
      />

      <Callout tone="warning" title="Product gap">
        Filtering by gradeId is correct. Content is almost entirely grade-9 Biology. Shipping
        “The Path” for all grades without gates will look broken.
      </Callout>

      <Divider />

      <H2>Security & data</H2>
      <Stack gap={12}>
        <Row gap={8} align="center">
          <Pill tone="deleted" size="sm">
            Critical
          </Pill>
          <Text>POST /api/path/progress accepts any phone + body. No CSRF, no rate limit.</Text>
        </Row>
        <Row gap={8} align="center">
          <Pill tone="deleted" size="sm">
            Critical
          </Pill>
          <Text>GET /api/path/progress returns every stored student Path blob.</Text>
        </Row>
        <Row gap={8} align="center">
          <Pill tone="warning" size="sm">
            High
          </Pill>
          <Text>progress.json is PII (phone) on disk beside CMS; fine for local, not SaaS.</Text>
        </Row>
        <Row gap={8} align="center">
          <Pill tone="info" size="sm">
            Note
          </Pill>
          <Text>Local SharedPreferences is fine for offline; treat server as backup only after auth.</Text>
        </Row>
      </Stack>

      <Divider />

      <H2>Ship checklist</H2>
      <Grid columns={2} gap={16}>
        <Card>
          <CardHeader>Before any public build</CardHeader>
          <CardBody>
            <Stack gap={6}>
              <Text>1. Auth on progress write; remove or gate GET</Text>
              <Text>2. Release: assets-only Path unless CONTENT_API_BASE set</Text>
              <Text>3. Empty-state UI when filtered levels.length === 0</Text>
              <Text>4. Namespace progress keys: gradeId:levelId</Text>
              <Text>5. Lock check on PathLevelPlayScreen entry</Text>
            </Stack>
          </CardBody>
        </Card>
        <Card>
          <CardHeader>Before calling it complete</CardHeader>
          <CardBody>
            <Stack gap={6}>
              <Text>6. Seed G10/G11/G12 gates (or hide Path by grade)</Text>
              <Text>7. Daily from CMS + visible gradeIds</Text>
              <Text>8. Pull+merge progress on app start</Text>
              <Text>9. Math Answer: numeric tolerance / aliases</Text>
              <Text>10. G12 UX: per-grade Paths or chapter hubs</Text>
            </Stack>
          </CardBody>
        </Card>
      </Grid>

      <Divider />

      <H2>Bottom line</H2>
      <Stack gap={8}>
        <H3>Production?</H3>
        <Text>
          No for multi-grade production. Yes as a closed Grade 9 Biology Path beta if you
          disable or lock the progress API and ship with bundled assets only.
        </Text>
        <Text tone="secondary">
          Strongest parts: grade filter, combat, CMS authoring. Weakest: trust boundary on
          progress, content coverage, restore sync.
        </Text>
      </Stack>
    </Stack>
  );
}
