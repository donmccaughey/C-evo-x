{$INCLUDE switches}

unit Diplomacy;

interface

uses Protocol;

function DipCommandToString(pSender, pTarget, Treaty, OppCommand, Command: integer;
  const OppOffer, Offer: TOffer): string;

implementation

uses
ScreenTools,Tribes,SysUtils;

function DipCommandToString;

  function PriceToString(p, Price: integer): string;
  begin
  case Price and opMask of
    opChoose:
      result:=Phrases.Lookup('PRICE_CHOOSE');
    opCivilReport:
      result:=Tribe[p].TPhrase('PRICE_CIVIL');
    opMilReport:
      result:=Tribe[p].TPhrase('PRICE_MIL');
    opMap:
      result:=Tribe[p].TPhrase('PRICE_MAP');
    opTreaty:
      {if Price-opTreaty<Treaty then
        case Treaty of
          trPeace: result:=Phrases.Lookup('FRENDTREATY_PEACE');
          trFriendlyContact: result:=Phrases.Lookup('FRENDTREATY_FRIENDLY');
          trAlliance: result:=Phrases.Lookup('FRENDTREATY_ALLIANCE');
          end
      else} result:=Phrases.Lookup('TREATY',Price-opTreaty);
    opShipParts:
      case Price shr 16 and $f of
        0: result:=Format(Phrases.Lookup('PRICE_SHIPCOMP'),[Price and $FFFF]);
        1: result:=Format(Phrases.Lookup('PRICE_SHIPPOW'),[Price and $FFFF]);
        2: result:=Format(Phrases.Lookup('PRICE_SHIPHAB'),[Price and $FFFF]);
        end;
    opMoney:
      result:=Format('%d%%c',[Price-opMoney]);
    opTribute:
      result:=Format(Phrases.Lookup('PRICE_TRIBUTE'),[Price-opTribute]);
    opTech:
      result:=Phrases.Lookup('ADVANCES',Price-opTech);
    opAllTech:
      result:=Tribe[p].TPhrase('PRICE_ALLTECH');
    opModel:
      result:=Tribe[p].ModelName[Price-opModel];
    opAllModel:
      result:=Tribe[p].TPhrase('PRICE_ALLMODEL');
{    opCity:
      result:=Format(TPhrase('PRICE_CITY',p),[CityName(Price-opCity)]);}
    end
  end;

var
i: integer;
sAdd,sDeliver, sCost: string;
DoIntro: boolean;
begin
DoIntro:= OppCommand=scDipStart;
case Command of
  scDipCancelTreaty:
    begin
    case Treaty of
      trPeace: result:=Phrases.Lookup('FRCANCELTREATY_PEACE');
      trFriendlyContact: result:=Phrases.Lookup('FRCANCELTREATY_FRIENDLY');
      trAlliance: result:=Phrases.Lookup('FRCANCELTREATY_ALLIANCE');
      end;
    DoIntro:=false;
    end;
  scDipNotice: result:=Phrases.Lookup('FRNOTICE');
  scDipAccept:
    begin
    if (OppOffer.nDeliver+OppOffer.nCost=1)
      and (OppOffer.Price[0] and opMask=opTreaty)
      and (integer(OppOffer.Price[0]-opTreaty)>Treaty) then // simple treaty offer
      {if OppOffer.Price[0]-opTreaty=trCeaseFire then
        result:=Tribe[pTarget].TPhrase('FRACCEPTCEASEFIRE')
      else} result:=Tribe[pTarget].TPhrase('FRACCEPTTREATY')
    else if OppOffer.nDeliver=0 then
      result:=Tribe[pSender].TPhrase('FRACCEPTDEMAND_STRONG')
    else if OppOffer.nCost=0 then
      result:=Tribe[pSender].TPhrase('FRACCEPTPRESENT')
    else result:=Tribe[pSender].TPhrase('FRACCEPTOFFER');
    end;
  scDipBreak:
    begin
    result:=Tribe[pTarget].TPhrase('FRBREAK');
    DoIntro:=false;
    end;
  scDipOffer:
    begin
    result:='';
    if (OppCommand=scDipOffer) and ((OppOffer.nDeliver>0) or (OppOffer.nCost>0))
      and (Offer.nCost+Offer.nDeliver<=2) then
      begin // respond to made offer before making own one
      if (OppOffer.nDeliver+OppOffer.nCost=1)
        and (OppOffer.Price[0] and opMask=opTreaty)
        and (integer(OppOffer.Price[0]-opTreaty)>Treaty) then // simple treaty offer
        result:=Tribe[pSender].TPhrase('FRNOTACCEPTTREATY')+'\'
      else if OppOffer.nDeliver=0 then
        result:=Tribe[pSender].TPhrase('FRNOTACCEPTDEMAND_STRONG')+'\'
      else if OppOffer.nCost=0 then
        result:=Tribe[pSender].TPhrase('FRNOTACCEPTPRESENT')+'\';
      end;

    sDeliver:='';
    for i:=0 to Offer.nDeliver-1 do
      begin
      sAdd:=PriceToString(pSender,Offer.Price[i]);
      if i=0 then sDeliver:=sAdd
      else sDeliver:=Format(Phrases.Lookup('PRICE_CONCAT'),[sDeliver,sAdd])
      end;
    sCost:='';
    for i:=0 to Offer.nCost-1 do
      begin
      sAdd:=PriceToString(pTarget,Offer.Price[Offer.nDeliver+i]);
      if i=0 then sCost:=sAdd
      else sCost:=Format(Phrases.Lookup('PRICE_CONCAT'),[sCost,sAdd])
      end;

    if (Offer.nDeliver=0) and (Offer.nCost=0) then
      begin // no offer made
      if (OppCommand=scDipOffer) and ((OppOffer.nDeliver=0) and (OppOffer.nCost=0)) then
        result:=Tribe[pTarget].TPhrase('FRBYE')
      else
        begin
        if (result='') and (OppCommand=scDipOffer)
          and ((OppOffer.nDeliver>0) or (OppOffer.nCost>0)) then
          begin
          if (OppOffer.nDeliver=1) and (OppOffer.Price[0]=opChoose)
            and not Phrases2FallenBackToEnglish then
            result:=Tribe[pSender].TString(Phrases2.Lookup('FRNOTACCEPTANYOFFER'))+' '
          else if (OppOffer.nCost=1) and (OppOffer.Price[OppOffer.nDeliver]=opChoose)
            and not Phrases2FallenBackToEnglish then
            result:=Tribe[pSender].TString(Phrases2.Lookup('FRNOTACCEPTANYWANT'))+' '
          else result:=Tribe[pSender].TPhrase('FRNOTACCEPTOFFER')+' ';
          end;
        result:=result+Phrases.Lookup('FRDONE');
        DoIntro:=false
        end
      end
    else if (Offer.nDeliver+Offer.nCost=1)
      and (Offer.Price[0] and opMask=opTreaty)
      and (integer(Offer.Price[0]-opTreaty)>Treaty) then // simple treaty offer
      begin
      case Offer.Price[0]-opTreaty of
        //trCeaseFire: result:=result+Tribe[pTarget].TPhrase('FRCEASEFIRE');
        trPeace: result:=result+Tribe[pTarget].TPhrase('FRPEACE');
        trFriendlyContact: result:=result+Tribe[pTarget].TPhrase('FRFRIENDLY');
        trAlliance: result:=result+Tribe[pTarget].TPhrase('FRALLIANCE');
        end
      end
    else if Offer.nDeliver=0 then // demand
      begin
      if (Treaty>=trFriendlyContact) and not Phrases2FallenBackToEnglish then
        result:=result+Format(Tribe[pTarget].TString(Phrases2.Lookup('FRDEMAND_SOFT')),[sCost])
      else
        begin
        result:=result+Format(Tribe[pTarget].TPhrase('FRDEMAND_STRONG'),[sCost]);
        DoIntro:=false
        end
      end
    else if Offer.nCost=0 then // present
      result:=result+Format(Tribe[pTarget].TPhrase('FRPRESENT'),[sDeliver])
    else if (Offer.nDeliver=1) and (Offer.Price[0]=opChoose) then
      result:=result+Format(Phrases.Lookup('FRDELCHOICE'),[sCost])
    else if (Offer.nCost=1) and (Offer.Price[Offer.nDeliver]=opChoose) then
      result:=result+Format(Phrases.Lookup('FRCOSTCHOICE'),[sDeliver])
    else result:=result+Format(Phrases.Lookup('FROFFER'),[sDeliver,sCost]);
    end;
  end;
if DoIntro then
  if Treaty<trPeace then
    result:=Tribe[pSender].TPhrase('FRSTART_NOTREATY')+' '+result
  else result:=Tribe[pSender].TPhrase('FRSTART_PEACE')+' '+result
end;

end.

