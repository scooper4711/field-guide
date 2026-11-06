import Foundation

extension RulesDiagrams {
    /// How a creature moves between unnoticed, undetected, hidden and observed, and where concealed
    /// fits, from the rules of Hide, Sneak, Seek, Avoid Notice, Create a Diversion and Point Out.
    static let detection = """
        <svg class="rules-diagram detection" viewBox="0 0 360 590" role="img"
             aria-label="How a creature moves between unnoticed, undetected, hidden and observed">
        <defs>
          <marker id="detection-hide" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7"
                  orient="auto-start-reverse"><path class="head hide" d="M0 0L10 5L0 10z"/></marker>
          <marker id="detection-found" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7"
                  orient="auto-start-reverse"><path class="head found" d="M0 0L10 5L0 10z"/></marker>
          <marker id="detection-condition" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7"
                  orient="auto-start-reverse"><path class="head condition" d="M0 0L10 5L0 10z"/></marker>
        </defs>

        <g class="state"><rect x="115" y="4" width="130" height="46" rx="6"/>
          <text class="name" x="180" y="23">Unnoticed</text>
          <text class="effect" x="180" y="39">Unaware you're there</text></g>
        <g class="state"><rect x="115" y="118" width="130" height="58" rx="6"/>
          <text class="name" x="180" y="137">Undetected</text>
          <text class="effect" x="180" y="152">Doesn't know your space;</text>
          <text class="effect" x="180" y="165">can't target you; off-guard</text></g>
        <g class="state"><rect x="115" y="272" width="130" height="58" rx="6"/>
          <text class="name" x="180" y="291">Hidden</text>
          <text class="effect" x="180" y="306">Knows your space;</text>
          <text class="effect" x="180" y="319">DC 11 flat check; off-guard</text></g>
        <g class="state"><rect x="115" y="426" width="130" height="58" rx="6"/>
          <text class="name" x="180" y="445">Observed</text>
          <text class="effect" x="180" y="460">Knows your space;</text>
          <text class="effect" x="180" y="473">targets you normally</text></g>
        <g class="state condition"><rect x="115" y="526" width="130" height="58" rx="6"/>
          <text class="name" x="180" y="545">Concealed</text>
          <text class="effect" x="180" y="560">Still observed;</text>
          <text class="effect" x="180" y="573">DC 5 flat check to target</text></g>

        <!-- Unnoticed to undetected -->
        <path class="move hide" d="M180 50V116" marker-end="url(#detection-hide)"/>
        <text class="trigger" x="188" y="79">Avoid Notice beats</text>
        <text class="trigger" x="188" y="92">their Perception DC</text>

        <!-- Undetected to hidden, and back -->
        <path class="move found" d="M160 176V270" marker-end="url(#detection-found)"/>
        <text class="trigger left" x="152" y="203">Seek: success</text>
        <text class="trigger left" x="152" y="216">Sneak: failure</text>
        <text class="trigger left" x="152" y="229">You speak or make noise</text>
        <text class="trigger left" x="152" y="242">An ally Points Out you</text>
        <path class="move hide" d="M200 272V178" marker-end="url(#detection-hide)"/>
        <text class="trigger" x="208" y="229">Sneak: success</text>

        <!-- Hidden to observed, and back -->
        <path class="move found" d="M160 330V424" marker-end="url(#detection-found)"/>
        <text class="trigger left" x="152" y="357">Seek: success</text>
        <text class="trigger left" x="152" y="370">Sneak: critical failure</text>
        <text class="trigger left" x="152" y="383">No cover or concealment</text>
        <text class="trigger left" x="152" y="396">You act</text>
        <path class="move hide" d="M200 426V332" marker-end="url(#detection-hide)"/>
        <text class="trigger" x="208" y="357">Hide: success, with</text>
        <text class="trigger" x="208" y="370">cover or concealment</text>
        <text class="trigger" x="208" y="383">Create a Diversion:</text>
        <text class="trigger" x="208" y="396">success (this turn)</text>

        <!-- Observed and concealed: the surroundings, not an action -->
        <path class="move condition" d="M180 488V522" marker-start="url(#detection-condition)" \
        marker-end="url(#detection-condition)"/>
        <text class="trigger" x="190" y="502">In fog, dim light,</text>
        <text class="trigger" x="190" y="515">smoke or similar</text>

        <!-- Undetected straight to observed -->
        <path class="move found" d="M245 147H346V455H247" marker-end="url(#detection-found)"/>
        <text class="trigger left" x="340" y="288">As from hidden,</text>
        <text class="trigger left" x="340" y="301">but Seek needs a</text>
        <text class="trigger left" x="340" y="314">critical success</text>
        </svg>
        """
}
