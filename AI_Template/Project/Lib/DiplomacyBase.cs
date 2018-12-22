using System;
using System.Collections.Generic;
using AI;

namespace CevoAILib.Diplomacy
{
	interface ITradeItem
	{
		int Code { get; }
	}

	class ItemOfChoice : ITradeItem
	{
		public int Code { get { return Protocol.opChoose; } }
		public ItemOfChoice() { }

		public override string ToString()
		{
			return "ItemOfChoice";
		}
	}

	class CopyOfMap : ITradeItem
	{
		public int Code { get { return Protocol.opMap; } }
		public CopyOfMap() { }

		public override string ToString()
		{
			return "CopyOfMap";
		}
	}

	class CopyOfDossier : ITradeItem
	{
		public readonly Nation Nation;
		public readonly int TurnOfReport;
		public CopyOfDossier(Nation nation) { this.Nation = nation; this.TurnOfReport = 0; } // turn will be set by server
		public CopyOfDossier(Nation nation, int turnOfReport) { this.Nation = nation; this.TurnOfReport = turnOfReport; }
		public int Code { get { return Protocol.opCivilReport + (Nation.ID << 16) + TurnOfReport; } }

		public override string ToString()
		{
			return string.Format("CopyOfDossier {0}", Nation);
		}
	}

	class CopyOfMilitaryReport : ITradeItem
	{
		public readonly Nation Nation;
		public readonly int TurnOfReport;
		public CopyOfMilitaryReport(Nation nation) { this.Nation = nation; this.TurnOfReport = 0; } // turn will be set by server
		public CopyOfMilitaryReport(Nation nation, int turnOfReport) { this.Nation = nation; this.TurnOfReport = turnOfReport; }
		public int Code { get { return Protocol.opMilReport + (Nation.ID << 16) + TurnOfReport; } }

		public override string ToString()
		{
			return string.Format("CopyOfMilitaryReport {0}", Nation);
		}
	}

	class Payment : ITradeItem
	{
		public readonly int Amount;
		public Payment(int amount) { this.Amount = amount; }
		public int Code { get { return Protocol.opMoney + Amount; } }

		public override string ToString()
		{
			return string.Format("Payment {0}", Amount);
		}
	}

	class TeachAdvance : ITradeItem
	{
		public readonly Advance Advance;
		public TeachAdvance(Advance advance) { this.Advance = advance; }
		public int Code { get { return Protocol.opTech + (int)Advance; } }

		public override string ToString()
		{
			return string.Format("TeachAdvance {0}", Advance);
		}
	}

	class TeachAllAdvances : ITradeItem
	{
		public int Code { get { return Protocol.opAllTech; } }
		public TeachAllAdvances() { }

		public override string ToString()
		{
			return "TeachAllAdvances";
		}
	}

	class TeachModel : ITradeItem
	{
		public readonly ModelBase Model;
		readonly int indexInSharedMemory;
		public TeachModel(Model model) { this.Model = model; indexInSharedMemory = model.IndexInSharedMemory; }
		public TeachModel(ForeignModel model) { this.Model = model; indexInSharedMemory = model.IndexInNationsSharedMemory; }
		public int Code { get { return Protocol.opModel + indexInSharedMemory; } }

		public override string ToString()
		{
			return string.Format("TeachModel {0}", Model);
		}
	}

	class TeachAllModels : ITradeItem
	{
		public int Code { get { return Protocol.opAllModel; } }
		public TeachAllModels() { }

		public override string ToString()
		{
			return "TeachAllModels";
		}
	}

	class ColonyShipPartLot : ITradeItem
	{
		public readonly Building PartType;
		public readonly int Number;
		public ColonyShipPartLot(Building partType, int number) { this.PartType = partType; this.Number = number; }
		public int Code { get { return Protocol.opShipParts + (((int)PartType - (int)Building.ColonyShipComponent) << 16) + Number; } }

		public override string ToString()
		{
			return string.Format("{0} x{1}", PartType, Number);
		}
	}

	class ChangeRelation : ITradeItem
	{
		public readonly Relation NewRelation;
		public ChangeRelation(Relation newRelation) { this.NewRelation = newRelation; }
		public int Code { get { return Protocol.opTreaty + (int)NewRelation - 1; } }

		public override string ToString()
		{
			return string.Format("ChangeRelation {0}", NewRelation);
		}
	}

	interface IStatement
	{
		int Command { get; }
	}

	class Notice : IStatement
	{
		public Notice() { }
		public int Command { get { return Protocol.scDipNotice; } }

		public override string ToString()
		{
			return "Notice";
		}
	}

	class AcceptTrade : IStatement
	{
		public AcceptTrade() { }
		public int Command { get { return Protocol.scDipAccept; } }

		public override string ToString()
		{
			return "AcceptTrade";
		}
	}

	class CancelTreaty : IStatement
	{
		public CancelTreaty() { }
		public int Command { get { return Protocol.scDipCancelTreaty; } }

		public override string ToString()
		{
			return "CancelTreaty";
		}
	}

	class SuggestTrade : IStatement
	{
		public int Command { get { return Protocol.scDipOffer; } }

		public readonly ITradeItem[] Offers;
		public readonly ITradeItem[] Wants;

		public SuggestTrade(ITradeItem[] offers, ITradeItem[] wants)
		{
			if (offers == null)
				this.Offers = new ITradeItem[0];
			else
				this.Offers = offers;
			if (wants == null)
				this.Wants = new ITradeItem[0];
			else
				this.Wants = wants;
		}

		unsafe public void FillRawStream(int* rawStream)
		{
			rawStream[0] = Offers.Length;
			for (int i = 0; i < Offers.Length; i++)
				rawStream[2 + i] = Offers[i].Code;
			rawStream[1] = Wants.Length;
			for (int i = 0; i < Wants.Length; i++)
				rawStream[2 + Offers.Length + i] = Wants[i].Code;
		}

		public override string ToString()
		{
			string offerString = "nothing";
			if (Offers.Length > 0)
			{
				offerString = Offers[0].ToString();
				for (int i = 1; i < Offers.Length; i++)
					offerString += " + " + Offers[i].ToString();
			}
			string wantString = "nothing";
			if (Wants.Length > 0)
			{
				wantString = Wants[0].ToString();
				for (int i = 1; i < Wants.Length; i++)
					wantString += " + " + Wants[i].ToString();
			}
			return "SuggestTrade " + offerString + " for " + wantString;
		}
	}

	class SuggestEnd : SuggestTrade
	{
		public SuggestEnd() : base(null, null) { }

		public override string ToString()
		{
			return "SuggestEnd";
		}
	}

	class Break : IStatement
	{
		public Break() { }
		public int Command { get { return Protocol.scDipBreak; } }

		public override string ToString()
		{
			return "Break";
		}
	}

	static class StatementFactory
	{
		static ITradeItem TradeItemFromCode(AEmpire empire, Nation source, int code)
		{
			switch (code & Protocol.opMask)
			{
				case Protocol.opChoose: return new ItemOfChoice();
				case Protocol.opMap: return new CopyOfMap();
				case Protocol.opCivilReport: return new CopyOfDossier(new Nation(empire, (code >> 16) & 0xFF), code & 0xFFFF);
				case Protocol.opMilReport: return new CopyOfMilitaryReport(new Nation(empire, (code >> 16) & 0xFF), code & 0xFFFF);
				case Protocol.opMoney: return new Payment(code & 0xFFFF);
				case Protocol.opTech: return new TeachAdvance((Advance)(code & 0xFFFF));
				case Protocol.opAllTech: return new TeachAllAdvances();
				case Protocol.opAllModel: return new TeachAllModels();
				case Protocol.opShipParts: return new ColonyShipPartLot((Building)((int)Building.ColonyShipComponent + (code >> 16) & 0xFF), code & 0xFFFF);
				case Protocol.opTreaty: return new ChangeRelation((Relation)((code & 0xFFFF) + 1));

				case Protocol.opModel:
					{
						if (source == empire.Us)
							return new TeachModel(empire.Models[code & 0xFFFF]);
						else
						{
							foreach (ForeignModel model in empire.ForeignModels)
							{
								if (model.Nation == source && model.IndexInNationsSharedMemory == (code & 0xFFFF))
									return new TeachModel(model);
							}
						}
						throw new Exception("Error in StatementFactory: Foreign model not found!");
					}

				default: throw new Exception("Error in StatementFactory: Not a valid trade item code!");
			}
		}

		unsafe public static IStatement OpponentStatementFromCommand(AEmpire empire, Nation opponent, int command, int* rawStream)
		{
			switch (command)
			{
				case Protocol.scDipNotice: return new Notice();
				case Protocol.scDipAccept: return new AcceptTrade();
				case Protocol.scDipCancelTreaty: return new CancelTreaty();
				case Protocol.scDipOffer:
					{
						if (rawStream[0] + rawStream[1] == 0)
							return new SuggestEnd();
						else
						{
							ITradeItem[] offers = new ITradeItem[rawStream[0]];
							if (rawStream[0] > 0)
							{
								for (int i = 0; i < rawStream[0]; i++)
									offers[i] = TradeItemFromCode(empire, opponent, rawStream[2 + i]);
							}
							ITradeItem[] wants = new ITradeItem[rawStream[1]];
							if (rawStream[1] > 0)
							{
								for (int i = 0; i < rawStream[1]; i++)
									wants[i] = TradeItemFromCode(empire, empire.Us, rawStream[2 + rawStream[0] + i]);
							}
							return new SuggestTrade(offers, wants);
						}
					}
				case Protocol.scDipBreak: return new Break();
				default: throw new Exception("Error in StatementFactory: Not a negotiation!");
			}
		}
	}

	struct ExchangeOfStatements
	{
		public IStatement OurStatement;
		public IStatement OpponentResponse;

		public ExchangeOfStatements(IStatement ourStatement, IStatement opponentResponse)
		{
			this.OurStatement = ourStatement;
			this.OpponentResponse = opponentResponse;
		}
	}

	sealed class Negotiation
	{
		AEmpire theEmpire;
		public readonly Phase Situation;
		public readonly Nation Opponent;
		public readonly List<ExchangeOfStatements> History = new List<ExchangeOfStatements>(); // sorted from new to old, newest at index 0
		IStatement ourNextStatement;
		public IStatement OurNextStatement { get { return ourNextStatement; } }

		public Negotiation(AEmpire empire, Phase negotiationSituation, Nation opponent)
		{
			this.theEmpire = empire;
			this.Situation = negotiationSituation;
			this.Opponent = opponent;
		}

		unsafe public PlayResult SetOurNextStatement(IStatement statement)
		{
			PlayResult result = PlayResult.Success;
			if (statement is SuggestTrade)
			{
				if (((SuggestTrade)statement).Offers.Length > 2 || ((SuggestTrade)statement).Wants.Length > 2)
					result = new PlayResult(PlayError.RulesViolation);

				// check model owners
				foreach (ITradeItem offer in ((SuggestTrade)statement).Offers)
				{
					if (offer is TeachModel && ((TeachModel)offer).Model.Nation != theEmpire.Us)
						result = new PlayResult(PlayError.RulesViolation);
				}
				foreach (ITradeItem want in ((SuggestTrade)statement).Wants)
				{
					if (want is TeachModel && ((TeachModel)want).Model.Nation != Opponent)
						result = new PlayResult(PlayError.RulesViolation);
				}

				if (result.OK)
				{
					fixed (int* tradeData = new int[14])
					{
						((SuggestTrade)statement).FillRawStream(tradeData);
						result = theEmpire.TestPlay(statement.Command, 0, tradeData);
					}
				}
			}
			else
				result = theEmpire.TestPlay(statement.Command);
			if (result.OK)
				ourNextStatement = statement;
			return result;
		}
	}
}
