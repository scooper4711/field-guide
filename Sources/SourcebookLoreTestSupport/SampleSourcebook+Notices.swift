/// The notices on a sample's last page that are worded by a license.
extension SampleSourcebook {
    /// The notice the Community Use Policy prescribes, for the deities' names and the art. Its wording is fixed
    /// (Tabletop Kit's `AboutInfo.communityUseNotice` is the same); only the product name is ours.
    var communityUseNotice: String {
        "\(title) uses trademarks and/or copyrights owned by Paizo Inc., used under Paizo's Community Use Policy "
            + "(paizo.com/licenses/communityuse). We are expressly prohibited from charging you to use or access "
            + "this content. \(title) is not published, endorsed, or specifically approved by Paizo. For more "
            + "information about Paizo Inc. and Paizo products, visit paizo.com."
    }

    /// The paragraph the Paizo Compatibility License requires, word for word, beside the other copyright notices.
    static let actionIconsNotice = """
        Pathfinder and Starfinder are registered trademarks and copyrights of Paizo Inc. The Pathfinder and \
        Starfinder Compatibility Logos are trademarks of Paizo Inc. The Pathfinder-Icons font is a copyright of \
        Paizo Inc. These trademarks and copyrights are used under the Paizo Compatibility License. See \
        paizo.com/licenses/compatibility for more information on this license.
        """

    static let orcNotice = """
        This product is licensed under the ORC License located at the Library of Congress at TX 9-307-067 and \
        available online at various locations including paizo.com/orclicense, azoralaw.com/orclicense, and others. \
        All warranties are disclaimed as set forth therein.
        """
}
