//
//  ScornadeTests.swift
//  ScornadeTests
//
//  Created by Jimmy Mieuzet on 15/06/2026.
//

import XCTest
@testable import Scornade

final class ScornadeTests: XCTestCase {

    // MARK: Fabriques

    private func entrants(_ names: String...) -> [Entrant] {
        names.enumerated().map { Entrant(name: $1, colorIndex: $0, playerIds: []) }
    }

    private func session(gameId: String, target: Int = 0, higherWins: Bool = false,
                         roundLimit: Int? = nil, phases: Bool = false) -> ScoreSession {
        ScoreSession(gameId: gameId, gameName: gameId, symbol: "",
                     target: target, higherWins: higherWins, direction: .accumulate,
                     entrants: entrants("A", "B", "C"),
                     roundLimit: roundLimit,
                     phaseRounds: phases ? [] : nil)
    }

    // MARK: Phase 10 — la dixième phase fait le vainqueur, pas les points

    func testPhaseCountsFromValidatedRounds() {
        var s = session(gameId: "phase10", phases: true)
        XCTAssertEqual(s.phase(of: 0), 1)

        for r in 0..<9 {
            s.phaseRounds?.append([true, r < 8, false])
            s.rounds.append([0, 5, 20])
        }
        XCTAssertEqual(s.phase(of: 0), 10)
        XCTAssertEqual(s.phase(of: 1), 9)
        XCTAssertEqual(s.phase(of: 2), 1, "Un joueur qui ne passe jamais reste en phase 1")
        XCTAssertFalse(s.isFinished)
    }

    func testGameEndsOnTenthPhaseNotOnPoints() {
        var s = session(gameId: "phase10", phases: true)
        for _ in 0..<10 {
            s.phaseRounds?.append([true, false, false])
            s.rounds.append([50, 0, 0])
        }
        XCTAssertEqual(s.phase(of: 0), 11)
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.winnerIndex, 0,
                       "Le vainqueur est celui qui a posé ses dix phases, même avec le plus gros passif")
    }

    func testPointsBreakTieBetweenFinishers() {
        var s = session(gameId: "phase10", phases: true)
        for _ in 0..<10 {
            s.phaseRounds?.append([true, true, false])
            s.rounds.append([10, 3, 0])
        }
        XCTAssertEqual(s.winnerIndex, 1, "À égalité de phases, le plus petit total gagne")
    }

    func testUndoingARoundGivesThePhaseBack() {
        var s = session(gameId: "phase10", phases: true)
        for _ in 0..<10 {
            s.phaseRounds?.append([true, false, false])
            s.rounds.append([5, 5, 5])
        }
        XCTAssertTrue(s.isFinished)

        s.phaseRounds?.removeLast()
        s.rounds.removeLast()
        XCTAssertEqual(s.phase(of: 0), 10)
        XCTAssertFalse(s.isFinished, "La partie repart si la manche qui la finissait est annulée")
    }

    // MARK: Les Cinq Rois — onze manches, ni plus ni moins

    func testRoundLimitEndsTheGame() {
        var s = session(gameId: "cinqrois", roundLimit: 11)
        for _ in 0..<10 { s.rounds.append([5, 8, 2]) }
        XCTAssertFalse(s.isFinished)

        s.rounds.append([5, 8, 2])
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.winnerIndex, 2, "Le plus petit total gagne")
    }

    // MARK: Belote — le litige à 81 partout

    private func deal(taker: Int = 0, points: [Int] = [81, 81],
                      belote: [Bool] = [false, false], capot: Int? = nil,
                      pending: Int = 0) -> BeloteRound {
        BeloteRound(takerTeam: taker, suit: "♠", cardPoints: points,
                    belote: belote, capotTeam: capot, pending: pending)
    }

    func testLitigeLeavesTheTakerWithNothing() {
        let r = deal()
        XCTAssertTrue(r.isLitige)
        XCTAssertEqual(r.deltas(), [0, 81],
                       "Le preneur ne marque rien, la défense marque ses 81 points")
        XCTAssertEqual(deal(taker: 1).deltas(), [81, 0])
    }

    func testBeloteSurvivesALitige() {
        XCTAssertEqual(deal(belote: [true, false]).deltas(), [20, 81],
                       "La belote du preneur reste acquise")
        XCTAssertEqual(deal(belote: [false, true]).deltas(), [0, 101])
    }

    func testLitigePointsGoToTheWinnerOfTheNextDeal() {
        var s = session(gameId: "belote", target: 501, higherWins: true)
        s.beloteRounds = [deal()]
        XCTAssertEqual(s.belotePending, 81, "Les 81 points du preneur restent en jeu")

        XCTAssertEqual(deal(points: [100, 62], pending: 81).deltas(), [181, 62],
                       "Contrat tenu : le preneur encaisse les points en jeu")
        XCTAssertEqual(deal(points: [70, 92], pending: 81).deltas(), [0, 243],
                       "Preneur dedans : la défense encaisse les 162 et les points en jeu")
        XCTAssertEqual(deal(points: [0, 0], capot: 1, pending: 81).deltas(), [0, 333],
                       "Capot : l'auteur du capot encaisse les points en jeu")
    }

    func testLitigesStackUpAndAreClearedByADecidedDeal() {
        var s = session(gameId: "belote", target: 501, higherWins: true)
        s.beloteRounds = [deal(), deal(pending: 81)]
        XCTAssertEqual(s.belotePending, 162, "Deux litiges de suite mettent 162 points en jeu")

        s.beloteRounds = [deal(), deal(points: [100, 62], pending: 81)]
        XCTAssertEqual(s.belotePending, 0, "Une donne tranchée solde l'ardoise")

        s.beloteRounds = []
        XCTAssertEqual(s.belotePending, 0)
    }

    func testOrdinaryDealsAreUnchangedByTheLitigeRule() {
        XCTAssertEqual(deal(points: [100, 62]).deltas(), [100, 62])
        XCTAssertEqual(deal(points: [82, 80]).deltas(), [82, 80], "82 pile tient le contrat")
        XCTAssertEqual(deal(points: [80, 82]).deltas(), [0, 162], "80 chute, tout part à la défense")
        XCTAssertEqual(deal(points: [0, 0], capot: 0).deltas(), [252, 0])
        XCTAssertFalse(deal(points: [100, 62]).isLitige)
    }

    func testDealsSavedBeforeTheLitigeRuleStillCount() {
        let old = BeloteRound(takerTeam: 0, suit: "♠", cardPoints: [100, 62],
                              belote: [false, false], capotTeam: nil)
        XCTAssertEqual(old.deltas(), [100, 62],
                       "Une donne enregistrée sans points en jeu se compte comme avant")
    }

    // MARK: Non-régression sur les jeux existants

    func testTargetGamesAreUnaffected() {
        var dekal = session(gameId: "dekal", target: 100)
        dekal.rounds = [[40, 10, 5], [70, 20, 8]]
        XCTAssertTrue(dekal.isFinished, "Dékal s'arrête dès qu'un joueur atteint 100")
        XCTAssertEqual(dekal.winnerIndex, 2)

        var uno = session(gameId: "uno", target: 500, higherWins: true)
        uno.rounds = [[100, 20, 5]]
        XCTAssertFalse(uno.isFinished)
        XCTAssertNil(uno.winnerIndex)
    }

    func testCatalogCarriesTheThreeNewGames() {
        for id in ["dekal", "phase10", "cinqrois"] {
            let game = GameCatalog.game(id: id)
            XCTAssertNotNil(game, "\(id) manque au catalogue")
            XCTAssertFalse(game?.rules.isEmpty ?? true, "\(id) n'a pas de règles")
        }
        XCTAssertEqual(GameCatalog.game(id: "cinqrois")?.roundLimit, 11)
        XCTAssertEqual(GameCatalog.game(id: "phase10")?.engine, .phaseRace)
    }
}
