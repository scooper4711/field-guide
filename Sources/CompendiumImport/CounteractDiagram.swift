import Foundation

extension RulesDiagrams {
    /// The counteract check: both counteract ranks, the check, and what each degree of success counteracts.
    static let counteract = """
        <svg class="rules-diagram counteract" viewBox="0 0 360 452" role="img"
             aria-label="How to counteract: find both counteract ranks, roll a counteract check, compare by degree \
        of success">
        <defs>
          <marker id="counteract-head" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7"
                  orient="auto"><path class="head" d="M0 0L10 5L0 10z"/></marker>
        </defs>

        <!-- Both counteract ranks -->
        <g class="step"><rect x="4" y="4" width="172" height="80" rx="6"/>
          <text class="name" x="90" y="23">Your rank</text>
          <text class="effect" x="90" y="40">Spell: its rank</text>
          <text class="effect" x="90" y="53">Otherwise: half its level,</text>
          <text class="effect" x="90" y="66">rounded up</text></g>
        <g class="step"><rect x="184" y="4" width="172" height="80" rx="6"/>
          <text class="name" x="270" y="23">Target's rank</text>
          <text class="effect" x="270" y="40">Spell: its rank</text>
          <text class="effect" x="270" y="53">Otherwise: half its level,</text>
          <text class="effect" x="270" y="66">rounded up (minimum 0)</text>
          <text class="effect" x="270" y="79">Unclear: half the creature's level</text></g>
        <path class="move" d="M90 84V100H180V114" marker-end="url(#counteract-head)"/>
        <path class="move" d="M270 84V100H180"/>

        <!-- The check -->
        <g class="step"><rect x="4" y="118" width="352" height="96" rx="6"/>
          <text class="name" x="180" y="137">Counteract check</text>
          <text class="effect term" x="180" y="154">Modifier</text>
          <text class="effect" x="180" y="167">Spell: spellcasting attribute + proficiency</text>
          <text class="effect" x="180" y="180">Otherwise: the relevant skill or listed modifier</text>
          <text class="effect term" x="180" y="196">against the DC</text>
          <text class="effect" x="180" y="209">Affliction: its stat block · Spell: its caster's DC · Otherwise: \
        GM's, by level</text></g>
        <path class="move" d="M180 214V234" marker-end="url(#counteract-head)"/>

        <!-- Degrees of success -->
        <text class="heading" x="8" y="252">Counteracts a target whose rank is</text>
        <text class="heading" x="352" y="252" text-anchor="end">Your rank 4</text>
        <g class="degree">
          <rect class="row" x="4" y="260" width="352" height="34" rx="4"/>
          <rect class="critical-success" x="4" y="260" width="5" height="34" rx="2"/>
          <text class="result" x="16" y="274">Critical success</text>
          <text x="16" y="287">Up to 3 higher than yours</text>
          <text class="example" x="348" y="281">Up to 7</text></g>
        <g class="degree">
          <rect class="row" x="4" y="298" width="352" height="34" rx="4"/>
          <rect class="success" x="4" y="298" width="5" height="34" rx="2"/>
          <text class="result" x="16" y="312">Success</text>
          <text x="16" y="325">Up to 1 higher than yours</text>
          <text class="example" x="348" y="319">Up to 5</text></g>
        <g class="degree">
          <rect class="row" x="4" y="336" width="352" height="34" rx="4"/>
          <rect class="failure" x="4" y="336" width="5" height="34" rx="2"/>
          <text class="result" x="16" y="350">Failure</text>
          <text x="16" y="363">Lower than yours</text>
          <text class="example" x="348" y="357">Up to 3</text></g>
        <g class="degree">
          <rect class="row" x="4" y="374" width="352" height="34" rx="4"/>
          <rect class="critical-failure" x="4" y="374" width="5" height="34" rx="2"/>
          <text class="result" x="16" y="388">Critical failure</text>
          <text class="never" x="16" y="401">Never</text>
          <text class="example never" x="348" y="395">Nothing</text></g>

        <text class="outcome" x="180" y="430">Counteracted: the target is disrupted and has no effect,</text>
        <text class="outcome" x="180" y="444">unless its description says otherwise.</text>
        </svg>
        """
}
