﻿class ItemScan
{
	__New(){
		This.Data := {}
		This.Data.ClipContents := RegExReplace(Clip_Contents, "<<.*?>>|<.*?>") ; Clipboard
		This.Data.Sections := StrSplit(This.Data.ClipContents, "`r`n--------`r`n")
		This.Data.Blocks := {}
		This.Pseudo := OrderedArray()
		This.Affix := OrderedArray()
		This.Prop := OrderedArray()
		This.Modifier := OrderedArray()
		This.Percent := {}
		; Split our sections from the clipboard
		; NamePlate, Affix, FlavorText, Enchant, Implicit, Influence, Corrupted
		For SectionKey, SVal in This.Data.Sections
		{
			If ((SVal ~= ":" || SVal ~= "Currently has \d+ Charges") && !(SVal ~= "grant:") && !(SVal ~= "slot:"))
			{
				If (SectionKey = 1 && SVal ~= "Rarity:")
					This.Data.Blocks.NamePlate := SVal, This.Prop.IsItem := true
				Else If (SVal ~= "{ Prefix" || SVal ~= "{ Suffix" || SVal ~= "{ Unique" )
					This.Data.Blocks.Affix := SVal
				Else If (SVal ~= " \(enchant\)$"){
					This.Prop.Enchanted := True
					This.Data.Blocks.Enchant := SVal
				}
				Else If (SVal ~= "Open Rooms:"){
					temp := StrSplit(SVal,"Obstructed Rooms:")
					This.Data.Blocks.TempleRooms := StrSplit(temp.1,"Open Rooms:").2
					This.Data.Blocks.ObstructedRooms := RegExReplace(temp.2, "$", " (Obstructed)")
				}
				Else
					This.Data.Blocks.Properties .= SVal "`r`n"
			}
			Else 
			{
				If (SVal ~= "\.$" || SVal ~= "\?$" || SVal ~= """$")
					This.Data.Blocks.FlavorText := SVal
				Else If (SVal ~= "\(implicit\)$"){
					This.Prop.HasImplicit := True
					This.Data.Blocks.Implicit := SVal
				}
				Else If (SVal ~= "Adds \d{1,} Passive Skills (enchant)")
					This.Data.Blocks.ClusterImplicit := SVal
				Else If (SVal ~= "\(enchant\)$"){
					This.Prop.HasEnchant := True
					This.Data.Blocks.Enchant := SVal
				}
				Else If (SVal ~= "\(scourge\)$")
					This.Data.Blocks.Scourge := SVal
				Else If (SVal ~= " Item$") && !(SVal ~= "\w{1,} \w{1,} \w{1,} Item$")
					This.Data.Blocks.Influence := SVal
				Else If (SVal ~= "^Scourged$") {
					This.Prop.Scourged := True
				}
				Else If (SVal ~= "^Corrupted$")
					This.Prop.Corrupted := True
				Else If (SVal ~= "^Abyss$")
					This.Prop.IsAbyss := True
				Else If (SVal ~= "^Unidentified$")
					This.Data.Blocks.Affix := SVal
				Else If (This.Data.Blocks.HasKey("Affix") || SVal ~= """.*""$")
					This.Data.Blocks.FlavorText := SVal
				Else
					This.Data.Blocks.Affix := SVal
			}
		}
			This.Data.Sections := ""
			This.Data.Delete("Sections")

		This.MatchAffixesWithoutDoubleMods(This.Data.Blocks.Affix)
		;This.MatchAffixes(This.Data.Blocks.Affix)
		This.MatchAffixes(This.Data.Blocks.Enchant)
		This.MatchAffixes(This.Data.Blocks.Scourge)
		This.MatchAffixes(This.Data.Blocks.Implicit)
		This.MatchAffixes(This.Data.Blocks.Influence)
		This.MatchAffixes(This.Data.Blocks.TempleRooms)
		This.MatchAffixes(This.Data.Blocks.ObstructedRooms)
		This.MatchAffixes(This.Data.Blocks.ClusterImplicit)
		This.MatchProperties()
		If (This.Prop.Rarity_Digit == 4 && !This.Affix["Unidentified"])
			This.ApproximatePerfection()
		This.MatchPseudoAffix()
		This.MatchExtenalDB()
		This.MatchCraftingBases()
		This.MatchBase2Slot()
		This.MatchChaosRegal()
		If (This.Prop.SlotType && ChaosRecipeEnableFunction)
			This.Prop.StashChaosItem := This.StashChaosRecipe(False)
		If (This.Prop.Rarity_Digit = 3 && !This.Affix.Unidentified && (StashTabYesPredictive && YesPredictivePrice != "Off")  ){
			This.Prop.PredictPrice := This.PredictPrice()
		}
		This.Prop.StashReturnVal := This.MatchStashManagement(false)
		; This.FuckingSugoiFreeMate()
		If (This.Prop.ClusterJewel) {
			This.Prop.ClusterSkills := 0
			This.Prop.ClusterSmall := 0
			For k, v in This.Affix {
				If InStr(k, "# Added Passive Skill is")
					This.Prop.ClusterSkills += 1
				If InStr(k, "Added Small Passive Skills also grant:")
					This.Prop.ClusterSmall += 1
			}
		}
	}
	; PredictPrice - Evaluate results from TradeFunc_DoPoePricesRequest
	PredictPrice(Switch:="")
	{
		Static ItemList := []
		Static WarnedError := 0
		FoundMatch := False
		If (This.Prop.Rarity_Digit != 3 || This.Affix.Unidentified)
			Return 0
		If (This.Prop.Rarity_Digit = 3 && (!This.Prop.SpecialType || This.Prop.SpecialType = "6Link" || This.Prop.SpecialType = "5Link") && YesPredictivePrice != "Off" )
		{
			For k, obj in ItemList
			{
				If (obj.Clip_Contents = Clip_Contents)
				{
					FoundMatch := True
					PriceObj := obj
					Break
				}
			}
			If !FoundMatch
			{
				PriceObj := TradeFunc_DoPoePricesRequest(Clip_Contents, "")
				if (PriceObj.error)
				{
					If (A_TickCount - WarnedError > 30000 )
					{
						Notify(PriceObj.error_msg, "", 10)
						WarnedError := A_TickCount
					}
					return
				}
				PriceObj.Clip_Contents := Clip_Contents
				If (YesPredictivePrice = "Low")
					Price := SelectedPrice := PriceObj.min
				Else If (YesPredictivePrice = "Avg")
					Price := SelectedPrice := (PriceObj.min + PriceObj.max) / 2
				Else If (YesPredictivePrice = "High")
					Price := SelectedPrice := PriceObj.max

				Price := Price * (YesPredictivePrice_Percent_Val / 100)
				PriceObj.Avg := (PriceObj.min + PriceObj.max) / 2
				PriceObj.Price := Price

				tt := "Priced using Machine Learning`n" Format("{1:0.3g}", PriceObj.min) " <<  " Format("{1:0.3g}", PriceObj.Avg ) "  >> " Format("{1:0.3g}", PriceObj.max) " @ " PriceObj.currency
					. "`nSelected Price: " YesPredictivePrice " (" Format("{1:0.3g}", SelectedPrice) ") " " multiplied by " YesPredictivePrice_Percent_Val "`%`nAffixes Influencing Price:"
				For k, reason in PriceObj.pred_explanation
					tt .= "`n" Round(reason.2 * 100) "`% " reason.1
				tt.= "`nEnd Of Predicive Price Information"
				PriceObj.tt := tt
				ItemList.Push(PriceObj)
			}
		}
		Else
			Return "000"

		If !(PriceObj.max > 0)
			Return "0000"

		If (Switch = "Obj")
			Return PriceObj
		Else
			Return PriceObj.Price
	}
	MatchProperties(){
		;Get total count of affixes
		This.Prop.AffixCount := 0
		This.Prop.PrefixCount := 0
		This.Prop.SuffixCount := 0
		This.Data.AffixNames := {Prefix:[],Suffix:[]}
		For k, v in StrSplit(This.Data.Blocks.Affix, "`n", "`r")
		{
			If (v = "")
			Continue
			; Flag curse on hit items
			If (v ~= "^Curse Enemies with .+ on Hit$")
				This.Prop.IsCurseOnHit := True
			If (v ~= "\{ Prefix Modifier"){
				If RegExMatch(v, "\{ Prefix Modifier ""(.+)"" \(Tier: (\d+)\) ?.? ?(.*) \}", rxm ) {
					This.Data.AffixNames.Prefix.Push({Name:rxm1,Tier:rxm2,Tags:(rxm3?rxm3:"")})
					This.Affix[rxm1] := This.Modifier[rxm1] := 1
				} Else If RegExMatch(v, "\{ Prefix Modifier ""(.+)"" . (.*) \}", rxm ) {
					This.Data.AffixNames.Prefix.Push({Name:rxm1,Tier:1,Tags:(rxm2?rxm2:"")})
					This.Affix[rxm1] := This.Modifier[rxm1] := 1
				} Else If RegExMatch(v, "\{ Prefix Modifier ""(.+)"" \}", rxm ) {
					This.Data.AffixNames.Prefix.Push({Name:rxm1,Tier:1,Tags:""})
					This.Affix[rxm1] := This.Modifier[rxm1] := 1
				}
				This.Prop.PrefixCount++, This.Prop.AffixCount++
			} Else If (v ~= "\{ Suffix Modifier") {
				If RegExMatch(v, "\{ Suffix Modifier ""(.+)"" \(Tier: (\d+)\) ?.? ?(.*) \}", rxm ) {
					This.Data.AffixNames.Suffix.Push({Name:rxm1,Tier:rxm2,Tags:(rxm3?rxm3:"")})
					This.Affix[rxm1] := This.Modifier[rxm1] := 1
				} Else If RegExMatch(v, "\{ Suffix Modifier ""(.+)"" . (.*) \}", rxm ) {
					This.Data.AffixNames.Suffix.Push({Name:rxm1,Tier:1,Tags:(rxm2?rxm2:"")})
					This.Affix[rxm1] := This.Modifier[rxm1] := 1
				} Else If RegExMatch(v, "\{ Suffix Modifier ""(.+)"" \}", rxm ) {
					This.Data.AffixNames.Suffix.Push({Name:rxm1,Tier:1,Tags:""})
					This.Affix[rxm1] := This.Modifier[rxm1] := 1
				}
				This.Prop.SuffixCount++, This.Prop.AffixCount++
			}
		}
		This.Prop.OpenAffix := 6 - This.Prop.PrefixCount - This.Prop.SuffixCount

		;Start NamePlate Parser
		If RegExMatch(This.Data.Blocks.NamePlate, "`am)Rarity: (.+)", RxMatch)
		{
			This.Prop.Rarity := RxMatch1
			If RegExMatch(This.Data.Blocks.NamePlate, "`am)Item Class: (.+)", RxMatch)
				This.Prop.ItemClass := RxMatch1
			;Prop Rarity Comparator
			If (InStr(This.Prop.Rarity, "Currency"))
			{
				This.Prop.RarityCurrency := True
			}
			Else If (InStr(This.Prop.Rarity, "Divination Card"))
			{
				This.Prop.RarityDivination := True
				This.Prop.SpecialType := "Divination Card"
			}
			Else If (InStr(This.Prop.Rarity, "Gem"))
			{
				This.Prop.RarityGem := True
				This.Prop.SpecialType := "Gem"
			}
			Else If (InStr(This.Prop.Rarity, "Normal"))
			{
				This.Prop.RarityNormal := True
				This.Prop.Rarity_Digit := 1
			}
			Else If (InStr(This.Prop.Rarity, "Magic"))
			{
				This.Prop.RarityMagic := True
				This.Prop.Rarity_Digit := 2
			}
			Else If (InStr(This.Prop.Rarity, "Rare"))
			{
				This.Prop.RarityRare := True
				This.Prop.Rarity_Digit := 3
			}
			Else If (InStr(This.Prop.Rarity, "Unique"))
			{
				This.Prop.RarityUnique := True
				This.Prop.Rarity_Digit := 4
			}
			; Fail Safe in case nothing match, to avoid auto-sell
			Else
			{
				This.Prop.SpecialType := This.Prop.Rarity
			}
			If (This.Prop.Rarity_Digit < 3)
				This.Prop.OpenAffix -= 4
			Else If (This.Prop.ItemClass ~= "Jewels" && This.Prop.Rarity_Digit = 3)
				This.Prop.OpenAffix -= 2
			; 4 Lines in NamePlate => Rarity / Item Name/ Item Base
			If (RegExMatch(This.Data.Blocks.NamePlate, "`r`n.+`r`n(.+)`r`n(.+)",RxMatch))
			{
				This.Prop.ItemName := RxMatch1
				This.Prop.ItemBase := RxMatch2
			}
			; 3 Lines in NamePlate => Rarity / Item Base
			Else If (RegExMatch(This.Data.Blocks.NamePlate, "`r`n.+`r`n(.+)",RxMatch))
			{
				This.Prop.ItemName := RxMatch1
				This.Prop.ItemBase := RxMatch1
			}
			If (This.Prop.ItemName ~= "^Superior ")
				This.Prop.ItemName := RegExReplace(This.Prop.ItemName, "^Superior ", "")
			If (This.Prop.ItemBase ~= "^Superior ")
				This.Prop.ItemBase := RegExReplace(This.Prop.ItemBase, "^Superior ", "")
			If (This.Prop.ItemBase ~= "^Synthesised ")
				This.Prop.ItemBase := RegExReplace(This.Prop.ItemBase, "^Synthesised ", "")
			If (This.Prop.RarityMagic){
				If (This.Prop.ItemBase ~= " of .+")
						This.Prop.ItemBase := RegExReplace(This.Prop.ItemBase, " of .+", "")
				For k, v in This.Data.AffixNames.Prefix {
					If (This.Prop.ItemBase ~= "^" v.Name)
						This.Prop.ItemBase := RegExReplace(This.Prop.ItemBase, "^" v.Name " ", "")
				}
			}
			;Start Parse
			
			; We match one of these against an item to identify its purpose
			If (This.Prop.ItemClass = "Misc Map Items")
			{
				This.Prop.MiscMapItem := True
				This.Prop.SpecialType := "Misc Map Item"
			}
			Else If (This.Prop.ItemClass = "Atlas Region Upgrade Items")
			{
				This.Prop.MiscMapItem := True
				This.Prop.SpecialType := "Atlas Watchstone"
			}
			Else If (This.Prop.ItemClass = "Maps")
			{
				This.Prop.IsMap := True
				; Deal with Blighted Map
				If (InStr(This.Prop.ItemBase, "Blighted"))
				{
					This.Prop.IsBlightedMap := True
					Prop.SpecialType := "Blighted Map"
				}
				Else
				{
					This.Prop.SpecialType := "Map"
				}
			}
			Else If (This.Prop.ItemBase ~= "Invitation:" && This.Data.Blocks.FlavorText ~= "Map Device")
			{
				This.Prop.SpecialType := "Invitation Map"
			}
			Else If (This.Prop.ItemBase ~= " Incubator$")
			{
				This.Prop.Incubator := True
				This.Prop.SpecialType := "Incubator"
			}
			Else If (InStr(This.Prop.ItemBase, "Timeless Karui Splinter") 
			|| InStr(This.Prop.ItemBase, "Timeless Eternal Empire Splinter") 
			|| InStr(This.Prop.ItemBase, "Timeless Vaal Splinter") 
			|| InStr(This.Prop.ItemBase, "Timeless Templar Splinter") 
			|| InStr(This.Prop.ItemBase, "Timeless Maraketh Splinter"))
			{
				This.Prop.TimelessSplinter := True
				This.Prop.SpecialType := "Timeless Splinter"
			}
			Else If (InStr(This.Prop.ItemBase, "Timeless Karui Emblem") 
			|| InStr(This.Prop.ItemBase, "Timeless Eternal Emblem") 
			|| InStr(This.Prop.ItemBase, "Timeless Vaal Emblem") 
			|| InStr(This.Prop.ItemBase, "Timeless Templar Emblem") 
			|| InStr(This.Prop.ItemBase, "Timeless Maraketh Emblem"))
			{
				This.Prop.TimelessEmblem := True
				This.Prop.SpecialType := "Timeless Emblem"
			}
			Else If (InStr(This.Prop.ItemBase, "Simulacrum"))
			{
				This.Prop.DeliriumSimulacrum := True
				This.Prop.SpecialType := "Delirium"
			}
			Else If (InStr(This.Prop.ItemBase, "Delirium Orb"))
			{
				This.Prop.DeliriumOrb := True
				This.Prop.SpecialType := "Delirium"
			}
			Else If (InStr(This.Prop.ItemBase, "Splinter of") && This.Prop.ItemClass ~= "Fragments")
			{
				This.Prop.BreachSplinter := True
				This.Prop.SpecialType := "Breach Splinter"
			}
			Else If (InStr(This.Prop.ItemBase, "Breachstone") && This.Prop.ItemClass ~= "Fragments")
			{
				This.Prop.BreachSplinter := True
				This.Prop.SpecialType := "Breachstone"
			}
			Else If (InStr(This.Prop.ItemBase, "Sacrifice at") && This.Prop.ItemClass ~= "Fragments")
			{
				This.Prop.SacrificeFragment := True
				This.Prop.MapPrep := True
				This.Prop.SpecialType := "Sacrifice Fragment"
			}
			Else If (InStr(This.Prop.ItemBase, "Mortal Grief") 
			|| InStr(This.Prop.ItemBase, "Mortal Hope") 
			|| InStr(This.Prop.ItemBase, "Mortal Ignorance")
			|| InStr(This.Prop.ItemBase, "Mortal Rage"))
			{
				This.Prop.MortalFragment := True
				This.Prop.SpecialType := "Mortal Fragment"
			}
			Else If (InStr(This.Prop.ItemBase, "Fragment of") && This.Prop.ItemClass ~= "Fragments")
			{
				This.Prop.GuardianFragment := True
				This.Prop.SpecialType := "Guardian Fragment"
			}
			Else If (InStr(This.Prop.ItemBase, "Volkuur's Key") 
			|| InStr(This.Prop.ItemBase, "Eber's Key")
			|| InStr(This.Prop.ItemBase, "Yriel's Key")
			|| InStr(This.Prop.ItemBase, "Inya's Key"))
			{
				This.Prop.ProphecyFragment := True
				This.Prop.SpecialType := "Prophecy Fragment"
			}
			Else If (InStr(This.Prop.ItemBase, "Scarab") && This.Prop.ItemClass ~= "Fragments")
			{
				This.Prop.Scarab := True
				This.Prop.MapPrep := True
				This.Prop.SpecialType := "Scarab"
			}
			Else If (InStr(This.Prop.ItemBase, "Offering to the Goddess") && This.Prop.ItemClass ~= "Fragments")
			{
				This.Prop.Offering := True
				This.Prop.SpecialType := "Offering"
			}
			Else If (InStr(This.Prop.ItemBase, "to the Goddess") && This.Prop.ItemClass ~= "Fragments")
			{
				This.Prop.UberDuberOffering := True
				This.Prop.SpecialType := "Uber Duber Offering"
			}
			Else If (InStr(This.Prop.ItemBase, "Essence of")
			|| InStr(This.Prop.ItemBase, "Remnant of Corruption"))
			{
				This.Prop.Essence := True
				This.Prop.SpecialType := "Essence"
			}
			Else If (This.Prop.RarityCurrency 
			&& (This.Prop.ItemBase ~= " Fossil$"))
			{
				This.Prop.Fossil := True
				This.Prop.SpecialType := "Fossil"
			}
			Else If (This.Prop.ItemClass ="Delve Stackable Socketable Currency")
			{
				This.Prop.Resonator := True
				This.Prop.SpecialType := "Resonator"
				If (InStr(This.Prop.ItemName, "Primitive") || InStr(This.Prop.ItemName, "Potent"))
					This.Prop.Item_Width := 1
				Else
					This.Prop.Item_Width := 2
				
				If (InStr(This.Prop.ItemName, "Primitive"))
					This.Prop.Item_Height := 1
				Else
					This.Prop.Item_Height := 2
			}
			Else If (InStr(This.Prop.ItemBase, "Divine Vessel"))
			{
				This.Prop.Vessel := True
				This.Prop.SpecialType := "Divine Vessel"
			}
			Else If (This.Prop.ItemClass = "Abyss Jewel")
			{
				This.Prop.AbyssJewel := True
				This.Prop.Jewel := True
			}
			Else If (This.Prop.ItemClass = "Jewels")
			{
				If (InStr(This.Prop.ItemBase, "Cluster Jewel"))
				{
					This.Prop.ClusterJewel := True
					This.Prop.SpecialType := "Cluster Jewel"
				}
				else
				{
					This.Prop.Jewel := True
				}
			}
			Else If (This.Prop.ItemClass = "Heist Targets")
			{
				This.Prop.Heist := True
				This.Prop.Vendorable := True
				This.Prop.SpecialType := "Heist Goods"
				This.Prop.Item_Width := This.Prop.Item_Height := 2
				If indexOf(This.Prop.ItemBase, HeistLootLarge)
					This.Prop.Item_Height := 4
			}
			Else If (InStr(This.Prop.ItemClass, "Flasks"))
			{
				This.Prop.Flask := True
				This.Prop.Item_Width := 1
				This.Prop.Item_Height := 2
			}
			Else If (This.Prop.ItemClass = "Quivers")
			{
				This.Prop.Quiver := True
				This.Prop.Item_Width := 2
				This.Prop.Item_Height := 3
			}
			Else If (This.Prop.ItemBase ~= " Artifact$")
			{
				This.Prop.Expedition := True
				This.Prop.Artifact := True
				This.Prop.SpecialType := "Expedition Artifact"
				If (This.Prop.ItemBase ~= "^Greater" || This.Prop.ItemBase ~= "^Grand")
					This.Prop.Item_Height := 2
				If (This.Prop.ItemBase ~= "^Grand")
					This.Prop.Item_Width := 2
			}
			Else if (indexOf(this.Prop.ItemBase, ["Exotic Coinage","Scrap Metal","Astragali","Burial Medallion"])) {
				This.Prop.Expedition := True
				This.Prop.ExpeditionCurrency := True
				This.Prop.SpecialType := "Expedition Currency"
			}
			Else If (InStr(This.Prop.ItemBase, "Expedition Logbook"))
			{
				This.Prop.Expedition := True
				This.Prop.SpecialType := "Expedition Logbook"
			}
			Else If (This.Prop.ItemBase ~= " Oil$")
			{
				If (This.Prop.RarityCurrency)
				{
					This.Prop.Oil := True
					This.Prop.SpecialType := "Oil"
				}
			}
			Else If (InStr(This.Prop.ItemBase, "Catalyst"))
			{
				If (This.Prop.RarityCurrency)
				{
				This.Prop.Catalyst := True
				This.Prop.SpecialType := "Catalyst"
				}
			}
			Else If (This.Prop.ItemClass = "Metamorph Sample")
			{
				If (InStr(This.Prop.ItemBase, "'s Lung"))
				{
					If (This.Prop.RarityUnique)
					{
						This.Prop.IsOrgan := "Lung"
						This.Prop.SpecialType := "Organ"
					}
				}
				Else If (InStr(This.Prop.ItemBase, "'s Heart"))
				{
					If (This.Prop.RarityUnique)
					{
						This.Prop.IsOrgan := "Heart"
						This.Prop.SpecialType := "Organ"
					}
				}
				Else If (InStr(This.Prop.ItemBase, "'s Brain"))
				{
					If (This.Prop.RarityUnique)
					{
						This.Prop.IsOrgan := "Brain"
						This.Prop.SpecialType := "Organ"
					}
				}
				Else If (InStr(This.Prop.ItemBase, "'s Liver"))
				{
					If (This.Prop.RarityUnique)
					{
						This.Prop.IsOrgan := "Liver"
						This.Prop.SpecialType := "Organ"
					}
				}
				Else If (InStr(This.Prop.ItemBase, "'s Eye"))
				{
					If (This.Prop.RarityUnique)
					{
						This.Prop.IsOrgan := "Eye"
						This.Prop.SpecialType := "Organ"
					}
				}
			}
			Else If (This.Prop.ItemClass = "Contracts")
			{
				This.Prop.Heist := True
				This.Prop.MapLikeItem := True
				This.Prop.SpecialType := "Heist Contract"
			}
			Else If (This.Prop.ItemClass = "Blueprints")
			{
				This.Prop.Heist := True
				This.Prop.MapLikeItem := True
				This.Prop.SpecialType := "Heist Blueprint"
			}
			Else If (InStr(This.Prop.ItemBase, "Thief's Trinket"))
			{
				This.Prop.HeistGear := True
				This.Prop.SpecialType := "Heist Tricket"
			}
			Else If (InStr(This.Prop.ItemBase, "Rogue's Marker"))
			{
				This.Prop.Heist := True
				This.Prop.SpecialType := "Heist Marker"
			}
			Else If (indexOf(This.Prop.ItemBase, HeistGear))
			{
				This.Prop.HeistGear := True
				This.Prop.SpecialType := "Heist Gear"
				If InStr(This.Prop.ItemBase, "Brooch")
					This.Prop.Item_Width := This.Prop.Item_Height := 1
				Else
					This.Prop.Item_Width := This.Prop.Item_Height := 2
			}
		}
		;End NamePlate Parser

		;Start Extra Blocks Parser
			;Parse Influence data block
		Loop, Parse,% This.Data.Blocks.Influence, `n, `r
		{
			; Match for influence type
			If (RegExMatch(A_LoopField, "`am)(.+) Item",RxMatch))
				This.Prop.Influence .= (This.Prop.Influence?" ":"") RxMatch1
		}
		If This.Prop.Influence {
			If (This.Prop.Influence ~= "Fractured" || This.Prop.Influence ~= "Synthesised")
				This.Prop.IsSynthesisItem := True
			Else 
				This.Prop.IsInfluenceItem := True
		}
		; Get Prophecy/Beasts using Flavour Txt
		If (RegExMatch(This.Data.Blocks.FlavorText, "Right-click to add this prophecy to your character",RxMatch))
		{
			This.Prop.Prophecy := True
			This.Prop.SpecialType := "Prophecy"
		}
			Else If (RegExMatch(This.Data.Blocks.FlavorText, "Right-click to add this to your bestiary",RxMatch))
		{
				This.Prop.IsBeast := True
				This.Prop.SpecialType := "Beast"
		}
		;End Extra Blocks Parser

		;Start Prop Block Parser for General Items
			;Every Item has a Item Level
		If (This.Prop.Rarity)
		{
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Item Level: "rxNum,RxMatch))
			{
				This.Prop.ItemLevel := RxMatch1
			}
			If (This.Data.Blocks.HasKey("Enchant"))
			{
				This.Prop.SpecialType := "Enchanted Item"
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Level: "rxNum,RxMatch))
			{
				This.Prop.Required_Level := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Str: "rxNum,RxMatch))
			{
				This.Prop.Required_Str := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Dex: "rxNum,RxMatch))
			{
				This.Prop.Required_Dex := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Int: "rxNum,RxMatch))
			{
				This.Prop.Required_Int := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Sockets: ([\w- ]+)",RxMatch))
			{
				This.Prop.Sockets_Raw := RxMatch1
				This.Prop.Sockets_Num := StrLen(RegExReplace(This.Prop.Sockets_Raw, "[- ]+" , ""))
				This.Prop.Sockets_Link := 0
				RegExReplace(RxMatch1, "R",, n)
				This.Prop.Sockets_R := n
				RegExReplace(RxMatch1, "G",, n)
				This.Prop.Sockets_G := n
				RegExReplace(RxMatch1, "B",, n)
				This.Prop.Sockets_B := n
				RegExReplace(RxMatch1, "W",, n)
				This.Prop.Sockets_W := n
				For k, v in StrSplit(RxMatch1, " ")
				{
					nlink := StrLen(RegExReplace(v, "\w" , "")) + 1
					if (This.Prop.Sockets_Link < nlink)
					{
						This.Prop.Sockets_Link := nlink
					}
					if (v ~= "R" && v ~= "G" && v ~= "B")
					{
						This.Prop.Chromatic := True
					}
				}
				If (This.Prop.Sockets_Link == 5 && YesSpecial5Link)
				{
					This.Prop.SpecialType := "5Link"
				}
				Else If (This.Prop.Sockets_Link == 6)
				{
					This.Prop.SpecialType := "6Link"
				}
				If (This.Prop.Sockets_Num == 6)
				{
					This.Prop.Jeweler := True
				}
			}
			;Generic Props
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Quality: \+"rxNum,RxMatch) && !IsMap)
			{
				This.Prop.Quality := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Armour: "rxNum,RxMatch))
			{
				This.Prop.Rating_Armour := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Energy Shield: "rxNum,RxMatch))
			{
				This.Prop.Rating_EnergyShield := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Evasion: "rxNum,RxMatch))
			{
				This.Prop.Rating_Evasion := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Chance to Block: "rxNum,RxMatch))
			{
				This.Prop.Rating_Block := RxMatch1
			}

			;Weapon Specific Props
				;Every Weapon has APS
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Attacks per Second: "rxNum,RxMatch))
			{
				This.Prop.IsWeapon := True
				This.Prop.Weapon_APS := RxMatch1
				If (RegExMatch(This.Data.Blocks.Properties, "`am)^Two Handed",RxMatch)){
					This.Prop.IsTwoHanded := True  
				}
				Else If (RegExMatch(This.Data.Blocks.Properties, "`am)^Staff",RxMatch)){
					This.Prop.IsTwoHanded := True  
				}
				Else If (RegExMatch(This.Data.Blocks.Properties, "`am)^Bow",RxMatch)){
					This.Prop.IsTwoHanded := True  
				}
				Else
				{
					This.Prop.IsOneHanded := True
				}
				If (RegExMatch(This.Data.Blocks.Properties, "`am)^Physical Damage: " rxNum "-" rxNum ,RxMatch))
				{
					This.Prop.Weapon_Avg_Physical_Dmg := Format("{1:0.3g}",(RxMatch1 + RxMatch2) / 2)
					This.Prop.Weapon_Min_Physical_Dmg := RxMatch1
					This.Prop.Weapon_Max_Physical_Dmg := RxMatch2
				}
				If (RegExMatch(This.Data.Blocks.Properties, "`am)^Chaos Damage: " rxNum "-" rxNum ,RxMatch))
				{
					This.Prop.Weapon_Avg_Chaos_Dmg := Format("{1:0.3g}",(RxMatch1 + RxMatch2) / 2)
					This.Prop.Weapon_Min_Chaos_Dmg := RxMatch1
					This.Prop.Weapon_Max_Chaos_Dmg := RxMatch2
				}
				If (RegExMatch(This.Data.Blocks.Properties, "`am)^Elemental Damage: .+",RxMatch))
				{
					This.Prop.Weapon_Avg_Elemental_Dmg := 0
					This.Prop.Weapon_Min_Elemental_Dmg := 0
					This.Prop.Weapon_Max_Elemental_Dmg := 0
					For k, v in StrSplit(RxMatch,",")
					{
						values := This.MatchLine(v)
						This.Prop.Weapon_Avg_Elemental_Dmg := Format("{1:0.3g}",This.Prop.Weapon_Avg_Elemental_Dmg + (values.1 + values.2) / 2 ) 
						This.Prop.Weapon_Min_Elemental_Dmg += values.1
						This.Prop.Weapon_Max_Elemental_Dmg += values.2
					}
					values := ""
				}
				If (RegExMatch(This.Data.Blocks.Properties, "`am)^Critical Strike Chance: "rxNum,RxMatch))
				{
					This.Prop.Weapon_Critical_Strike := RxMatch1
				}
				If (RegExMatch(This.Data.Blocks.Properties, "`am)^Weapon Range: "rxNum,RxMatch))
				{
					This.Prop.Weapon_Range := RxMatch1
				}
				This.Prop.Weapon_DPS_Total := 0
				This.Prop.Weapon_DPS_Total_Q20 := 0
				If (This.Prop.HasKey("Weapon_Avg_Physical_Dmg"))
					This.Prop.Weapon_DPS_Physical := Round(This.Prop.Weapon_Avg_Physical_Dmg * This.Prop.Weapon_APS,1)
				If (This.Prop.HasKey("Weapon_Avg_Elemental_Dmg"))
					This.Prop.Weapon_DPS_Elemental := Round(This.Prop.Weapon_Avg_Elemental_Dmg * This.Prop.Weapon_APS,1)
				If (This.Prop.HasKey("Weapon_Avg_Chaos_Dmg"))
					This.Prop.Weapon_DPS_Chaos := Round(This.Prop.Weapon_Avg_Chaos_Dmg * This.Prop.Weapon_APS,1)
				This.Prop.Weapon_DPS_Total := Round((This.Prop.Weapon_DPS_Physical?This.Prop.Weapon_DPS_Physical:0) + (This.Prop.Weapon_DPS_Elemental?This.Prop.Weapon_DPS_Elemental:0) + (This.Prop.Weapon_DPS_Chaos?This.Prop.Weapon_DPS_Chaos:0),1)
				If ((This.Prop.Quality?This.Prop.Quality:0) < 20 && This.Prop.HasKey("Weapon_Avg_Physical_Dmg"))
				{
					BasePhysDps := (This.Prop.Weapon_Avg_Physical_Dmg * This.Prop.Weapon_APS) / (((This.Prop.Quality?This.Prop.Quality:0) + 100) / 100)
					Q20DpsPhys := Round(BasePhysDps * (120 / 100),2)
					This.Prop.Weapon_DPS_Total_Q20 := Round(Q20DpsPhys + (This.Prop.Weapon_DPS_Elemental?This.Prop.Weapon_DPS_Elemental:0) + (This.Prop.Weapon_DPS_Chaos?This.Prop.Weapon_DPS_Chaos:0),1)
				}
				Else
					This.Prop.Weapon_DPS_Total_Q20 := This.Prop.Weapon_DPS_Total
			}
		}
		;End Prop Block Parser for General Items

		;Start Prop Block Parser for Maps
			;Every map has a Map Tier!
		If (RegExMatch(This.Data.Blocks.Properties, "`am)^Map Tier: "rxNum,RxMatch))
		{
			This.Prop.Map_Tier := RxMatch1
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Atlas Region: ([a-zA-Z0-9 ']+)",RxMatch))
			{
				This.Prop.Map_AtlasRegion := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Item Quantity: \+"rxNum,RxMatch))
			{
				This.Prop.Map_Quantity := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Item Rarity: \+"rxNum,RxMatch))
			{
				This.Prop.Map_Rarity := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Monster Pack Size: \+"rxNum,RxMatch))
			{
				This.Prop.Map_PackSize := RxMatch1
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Delirium Reward Type:",RxMatch))
			{
				This.Prop.Map_Delirium := True
			}
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Quality: \+"rxNum,RxMatch))
			{
				This.Prop.Map_Quality := RxMatch1
			}Else{
				;Set Quality to 0 if not in map prop (instead flagging as false)
				This.Prop.Map_Quality := 0
			}
		}
		;End Prop Block Parser for Maps
		
		; Start Prop Block Parser for Heist
		If indexOf(This.Prop.ItemClass, ["Contract","Blueprint"]) {
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Heist Target: (.*)",RxMatch))
				This.Prop.Heist_Target := RxMatch1
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Client: (.*)",RxMatch))
				This.Prop.Heist_Client := RxMatch1
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Area Level: " rxNum,RxMatch))
				This.Prop.Heist_AreaLevel := RxMatch1
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Item Quantity: \+" rxNum,RxMatch))
				This.Prop.Heist_ItemQuantity := RxMatch1
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Item Rarity: \+" rxNum,RxMatch))
				This.Prop.Heist_ItemRarity := RxMatch1
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Alert Level Reduction: \+" rxNum,RxMatch))
				This.Prop.Heist_AlertLevelReduction := RxMatch1
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Time Before Lockdown: \+" rxNum,RxMatch))
				This.Prop.Heist_TimeBeforeLockdown := RxMatch1
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Maximum Alive Reinforcements: \+" rxNum,RxMatch))
				This.Prop.Heist_MaximumAliveReinforcements := RxMatch1
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Wings Revealed: " rxNum "/" rxNum,RxMatch))
				This.Prop.Heist_WingsRevealed := RxMatch1, This.Prop.Heist_WingsRevealedMax := RxMatch2
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Escape Routes Revealed: " rxNum "/" rxNum,RxMatch))
				This.Prop.Heist_EscapeRoutesRevealed := RxMatch1, This.Prop.Heist_EscapeRoutesRevealedMax := RxMatch2
			If (RegExMatch(This.Data.Blocks.Properties, "`am)^Reward Rooms Revealed: " rxNum "/" rxNum,RxMatch))
				This.Prop.Heist_RewardRoomsRevealed := RxMatch1, This.Prop.Heist_RewardRoomsRevealedMax := RxMatch2
			For k, job in ["Brute Force","Agility","Perception","Demolition","Counter-Thaumaturgy","Trap Disarmament","Deception","Engineering","Lockpicking"] {
				If (RegExMatch(This.Data.Blocks.Properties, "`am)^Requires " job " \(Level " rxNum "\)",RxMatch)) {
					This.Prop["Heist_Requires" job ] := RxMatch1
				}
			}
		}
		; End Prop Block Parser for Heist
		;Start Prop Block Parser for Vaal Gems
		If (This.Prop.RarityGem && This.Prop.Corrupted)
		{
			If (RegExMatch(This.Data.Blocks.Properties, "`am)Vaal",RxMatch))
			{
				This.Prop.VaalGem := True
				This.Prop.ItemName := "Vaal " . This.Prop.ItemName
			}
		}
		;End Prop Block Parser for Vaal Gems

		If (This.Affix["Veiled Prefix"] || This.Affix["Veiled Suffix"])
		{
			This.Prop.Veiled := True
			This.Prop.SpecialType := "Veiled Item"
			For k, v in This.Modifier {
				If RegExMatch(k, "(.*) Veiled", rxm) {
					This.Prop.VeiledType := rxm1
					Break
				}
			}
		}
		Else
		{
			This.Prop.Veiled := False
		}
		; Flags for Map Roll and Bricked Maps
		If (This.HasBrickedAffix())
		{
			If (This.Prop.Corrupted)
			{
				;Set Flag for Bricked Map Stash
				This.Prop.IsBrickedMap := True
			}
			Else
			{
				;Set Flag for MapRoll
				This.Prop.HasUndesirableMod := True
			}
		}
		;Stack size for anything with it
		If (RegExMatch(This.Data.Blocks.Properties, "`am)^Stack Size: (\d.*)\/(\d.*)" ,RxMatch))
		{
			This.Prop.Stack_Size := RegExReplace(RxMatch1,"[\.,]","")
			This.Prop.Stack_Max := RegExReplace(RxMatch2,"[\.,]","")
		}
		If (RegExMatch(This.Data.Blocks.Properties, "`am)^Seed Tier: "rxNum,RxMatch))
		{
			This.Prop.Seed_Tier := RxMatch1
			This.Prop.IsSeed := True
		}
		If (This.Data.Blocks.FlavorText ~= "in the Sacred Grove")
			This.Prop.SpecialType := "Harvest Item"
		If (This.Data.Blocks.FlavorText ~= "Ritual Altar" || This.Data.Blocks.FlavorText ~= "Ritual Vessel")
			This.Prop.SpecialType := "Ritual Item", This.Prop.Ritual := True
		;Basics
		This.GetActualLifeTier()
		This.GetActualResistTier()
		This.GetActualMSTier()
		;Stats
		This.GetActualSTRTier()
		This.GetActualDEXTier()
		This.GetActualINTTier()
		This.GetActualAllAttributesTier()
		;Defenses
		This.GetActualSpellSuppressTier()
		This.GetActualESTier()
		This.GetActualIncESTier()
		This.GetActualArmourTier()
		This.GetActualIncArmourTier()
		This.GetActualEvasionTier()
		This.GetActualIncEvasionTier()
		;Hybrid INC
		This.GetActualIncArmourEvasionTier()
		This.GetActualIncArmourESTier()
		This.GetActualIncEvasionESTier()
		;Hybrid Defenses
		This.GetActualEvasionESTier()
		This.GetActualArmourESTier()
		This.GetActualArmourEvasionTier()
		This.GetActualArmourLifeTier()
		This.GetActualEvasionLifeTier()
		This.GetActualESLifeTier()
		This.GetActualESManaTier()
		;Damage Mods
		This.GetActualDamageModsTier()

	}
	HasBrickedAffix() {
		If ((This.Affix["Monsters have #% chance to Avoid Elemental Ailments"] && AvoidAilments) 
		|| (This.Affix["Monsters have a #% chance to avoid Poison, Blind, and Bleeding"] && AvoidPBB) 
		|| (This.Affix["Monsters reflect #% of Elemental Damage"] && ElementalReflect) 
		|| (This.Affix["Monsters reflect #% of Physical Damage"] && PhysicalReflect) 
		|| (This.Affix["Players cannot Regenerate Life, Mana or Energy Shield"] && NoRegen) 
		|| (This.Affix["Cannot Leech from Monsters"] && NoLeech)
		|| (This.Affix["-#% maximum Player Resistances"] && MinusMPR)
		|| (This.Affix["Monsters fire # additional Projectiles"] && MFAProjectiles)
		|| (This.Affix["Monsters deal #% extra Physical Damage as Fire"] && MDExtraPhysicalDamage)
		|| (This.Affix["Monsters deal #% extra Physical Damage as Cold"] && MDExtraPhysicalDamage)
		|| (This.Affix["Monsters deal #% extra Physical Damage as Lightning"] && MDExtraPhysicalDamage)
		|| (This.Affix["Monsters have #% increased Critical Strike Chance"] && MICSC)
		|| (This.Affix["Monsters' skills Chain # additional times"] && MSCAT)
		|| (This.Affix["Players have #% less Recovery Rate of Life and Energy Shield"] && LRRLES)
		|| (This.Affix["Player chance to Dodge is Unlucky"] && PCDodgeUnlucky)
		|| (This.Affix["Monsters have #% increased Accuracy Rating"] && MHAccuracyRating)
		|| (This.Affix["Players have #% reduced Chance to Block"] && PHReducedChanceToBlock)
		|| (This.Affix["Players have #% less Armour"] && PHLessArmour)
		|| (This.Affix["Players have #% less Area of Effect"] && PHLessAreaOfEffect)
		|| (This.HasCustomBrickedAffix()))
		{
			Return True
		} 
		Else 
		{
			Return False
		}
	}
	HasCustomBrickedAffix() {
		sum := 0
		good := 0
		For k, v in WR.CustomMapMods.CustomMods{
			if(v["Enable"] == 1 && This.Affix[v["Map Modifier"]])
			{
				if(v["Mod Type"] == "Impossible"){
					Return True
				}else if(v["Mod Type"] == "Good"){
					good++
					sum += v["Weight"]
				}else if(v["Mod Type"] == "Bad"){
					sum -= v["Weight"]
				}
			}
		}
		if(sum >= 0){
			If good
				This.Prop.HasDesirableMod := good
			Return False
		}else{
			Return True
		}
	}
	GetActualResistTier(){
		loop, 5
		{
			if (A_Index == 1)
			{
				Name:= "Chaos"
				AffixName:= ["#% to Chaos Resistance"]
				AffixList := ["of the Lost","of Banishment","of Eviction","of Expulsion","of Exile","of Bameth"]
				ILvLList := [16,30,44,56,65,81]
				if(This.HasAffix("of Tacati") && This.HasModifierFromList(AffixName))
				{
					This.Prop["ActualTier" Name "Resist"] := 1
					Continue
				}

			}else if (A_Index == 2){
				;Fire
				Name:= "Fire"
				AffixName:= ["#% to Fire Resistance"]
				AffixList := ["of the Whelpling","of the Salamander","of the Drake","of the Kiln","of the Furnace","of the Volcano","of the Magma","of Tzteosh"]
				ILvLList := [1,12,24,36,48,60,72,84]
				if(This.HasAffix("of Tacati") && This.HasModifierFromList(AffixName))
				{
					This.Prop["ActualTier" Name "Resist"] := 1
					Continue
				}

			}else if (A_Index == 3){
				;Cold
				Name:="Cold"
				AffixName:= ["#% to Cold Resistance"]
				AffixList := ["of the Inuit","of the Seal","of the Penguin","of the Yeti","of the Walrus","of the Polar Bear","of the Ice","of Haast"]
				ILvLList := [1,14,26,38,50,60,72,84]
				if(This.HasAffix("of Tacati") && This.HasModifierFromList(AffixName))
				{
					This.Prop["ActualTier" Name "Resist"] := 1
					Continue
				}
				
			}else if (A_Index == 4){
				;Lightning
				Name:="Lightning"
				AffixName:= ["#% to Lightning Resistance"]
				AffixList := ["of the Cloud","of the Squall","of the Storm","of the Thunderhead","of the Tempest","of the Maelstrom","of the Lightning","of Ephij"]
				ILvLList := [1,13,25,37,49,60,72,84]
				if(This.HasAffix("of Tacati") && This.HasModifierFromList(AffixName))
				{
					This.Prop["ActualTier" Name "Resist"] := 1
					Continue
				}
			}else if (A_Index == 5){
				; All Elemental
				Name:="AllElemental"
				AffixName:= ["#% to all Elemental Resistances"]
				AffixList := ["of the Crystal","of the Prism","of the Kaleidoscope","of Variegation","of the Rainbow","of the Span"]
				ILvLList := [12,24,36,48,60,85]
			}

			if(!This.HasModifierFromList(AffixName)){
				Continue
			}
		
			for k,v in ILvLList
			{
				if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
				{
					for ki,vi in AffixList
					{
						If (This.HasAffix(vi)){
							value := k-ki+1
							This.Prop["ActualTier" Name "Resist"] := value
							break
						}
					}
					break
				}
			}

		}
	}
	GetActualLifeTier(){
		AffixName:= ["# to maximum Life"]
		AffixList := ["Hale","Healthy","Sanguine","Stalwart","Stout","Robust","Rotund","Virile","Athlete's","Fecund","Vigorous","Rapturous","Prime"]
		ILvLList := []
		ILvLListRings := 				[1,5,11,18,24,30,36,44]
		ILvLListBootsGlovesAmulets := 	[1,5,11,18,24,30,36,44,54]
		ILvLListBeltsHelmetsQuivers := 	[1,5,11,18,24,30,36,44,54,64]
		ILvLListShields := 				[1,5,11,18,24,30,36,44,54,64,73]
		ILvLListBodyArmours := 			[1,5,11,18,24,30,36,44,54,64,73,81,86]

		if(indexOf(This.Prop.ItemClass,["Rings"])){
			ILvLList := ILvLListRings
		}else if(indexOf(This.Prop.ItemClass,["Boots","Gloves","Amulets"])){
			ILvLList := ILvLListBootsGlovesAmulets
		}else if(indexOf(This.Prop.ItemClass,["Belts","Helmets","Quivers"])){
			ILvLList := ILvLListBeltsHelmetsQuivers
		}else if(indexOf(This.Prop.ItemClass,["Shields"])){
			ILvLList := ILvLListShields
		}else if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}
		;Incursion Mod
		If (This.HasAffix("Guatelitzi's") && This.Affix["#% increased maximum Life"])
		{
			This.Prop["ActualTierLife"] := 1
			return
		}

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		for k,v in ILvLList
			{
				if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
				{
					for ki,vi in AffixList
					{
						If (This.HasAffix(vi)){
							value := k-ki+1
							This.Prop["ActualTierLife"] := value
							break
						}
					}
					break
				}
			}
	}
	GetActualMSTier(){
		AffixName:= ["#% increased Movement Speed"]
		ILvLList := []
		AffixList := ["Runner's","Sprinter's","Stallion's","Gazelle's","Cheetah's","Hellion's"]
		ILvLListBoots := [1,15,30,40,55,86]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Boots"])){
			ILvLList := ILvLListBoots
		}

		;Incursion Mod
		If (This.HasAffix("Matatl's") && This.Affix["#% increased Movement Speed"]){
			This.Prop["ActualTierMS"] := 1
			return
		}
		

		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierMS"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualSTRTier(){
		AffixName:= ["# to Strength"]
		AffixList := ["of the Brute","of the Wrestler","of the Bear","of the Lion","of the Gorilla","of the Goliath","of the Leviathan","of the Titan","of the Gods","of the Godslayer"]
		ILvLList := [1,11,22,33,44,55,66,74,82]
		ILvLListBelts := [1,11,22,33,44,55,66,74,82,85]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Belts"])){
			ILvLList := ILvLListBelts
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierSTR"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualDEXTier(){
		AffixName:= ["# to Dexterity"]
		AffixList := ["of the Mongoose","of the Lynx","of the Fox","of the Falcon","of the Panther","of the Leopard","of the Jaguar","of the Phantom","of the Wind","of the Blur"]
		ILvLList := [1,11,22,33,44,55,66,74,82]
		ILvLListQuiversGloves := [1,11,22,33,44,55,66,74,82,85]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Quivers","Gloves"])){
			ILvLList := ILvLListQuiversGloves
		}

		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierDEX"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualINTTier(){
		AffixName:= ["# to Intelligence"]
		AffixList := ["of the Pupil","of the Student","of the Prodigy","of the Augur","of the Philosopher","of the Sage","of the Savant","of the Virtuoso","of the Genius","of the Polymath"]
		ILvLList := [1,11,22,33,44,55,66,74,82]
		ILvLListHelmets := [1,11,22,33,44,55,66,74,82,85]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Helmets"])){
			ILvLList := ILvLListHelmets
		}

		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierINT"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualAllAttributesTier(){
		AffixName := ["# to all Attributes"]
		ILvLList := []
		AffixList := ["of the Clouds","of the Sky","of the Meteor","of the Comet","of the Heavens","of the Galaxy","of the Universe","of the Infinite","of the Multiverse"]
		ILvLListRings := [1,11,22,33]
		ILvLListAmulets := [1,11,22,33,44,55,66,77,85]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Rings"])){
			ILvLList := ILvLListRings
		}else if(indexOf(This.Prop.ItemClass,["Amulets"])){
			ILvLList := ILvLListAmulets
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierAllAttributes"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualIncESTier(){
		AffixName := ["#% increased Energy Shield","#% increased maximum Energy Shield"]
		ILvLList := []
		AffixList := ["Protective","Strong-Willed","Resolute","Fearless","Dauntless","Indomitable","Unassailable","Unfaltering"]
		ILvLListBodyArmoursShields := [3,18,30,44,60,72,84,86]
		ILvLListHelmetsGlovesBoots:= [3,18,30,44,60,72,84]
		ILvLListAmulets:= [3,18,30,42,56,70,77]
		
		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours","Shields"])){
			ILvLList := ILvLListBodyArmoursShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Gloves","Boots"])){
			ILvLList := ILvLListHelmetsGlovesBoots
		}else if(indexOf(This.Prop.ItemClass,["Amulets"])){
			ILvLList := ILvLListAmulets
		}

		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierIncES"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualESTier(){
		AffixName := ["# to maximum Energy Shield"]
		ILvLList := []
		AffixList := ["Shining","Glimmering","Glittering","Glowing","Radiating","Pulsing","Seething","Blazing","Scintillating","Incandescent","Resplendent","Dazzling"]
		ILvLListBodyArmours:= 	[3,11,17,23,29,35,43,51,60,69,75]
		ILvLListRings:= 		[3,11,17,23,29,35,42,50,59,68,74]
		ILvLListAmulets:= 		[3,11,17,23,29,35,42,50,59,68,74,80]
		ILvLListShields:= 		[3,11,17,23,29,35,43,51,60,69]
		ILvLListHelmets:= 		[3,11,17,23,29,35,43,51]
		ILvLListGlovesBoots:= 	[3,11,17,23,29,35,43]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		;Incursion Mod
		If (This.HasAffix("Guatelitzi's") && This.Affix["#% increased maximum Energy Shield"]){
			This.Prop["ActualTierES"] := 1
			return
		}

		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Shields"])){
			ILvLList := ILvLListShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets"])){
			ILvLList := ILvLListHelmets
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}else if(indexOf(This.Prop.ItemClass,["Rings"])){
			ILvLList := ILvLListRings
		}else if(indexOf(This.Prop.ItemClass,["Amulets"])){
			ILvLList := ILvLListAmulets
		}

		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierES"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualArmourTier(){
		AffixName := ["# to Armour"]
		ILvLList := []
		AffixList := ["Lacquered","Studded","Ribbed","Fortified","Plated","Carapaced","Encased","Enveloped","Abating","Unmoving","Impervious"]
		ILvLListBodyArmours:= 	[1,11,17,23,29,35,43,51,60,69,77]
		ILvLListGlovesBoots:= 	[1,11,17,23,29,35,43]
		ILvLListHelmets:= 	[1,11,17,23,29,35,43,51]
		ILvLListShields:= [1,11,17,23,29,35,43,51,60,69]
		ILvLListBelts:= [1,18,30,44,57,71,83,86]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Shields"])){
			ILvLList := ILvLListShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets"])){
			ILvLList := ILvLListHelmets
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}else if(indexOf(This.Prop.ItemClass,["Belts"])){
			ILvLList := ILvLListBelts
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierArmour"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualIncArmourTier(){
		AffixName := ["#% increased Armour"]
		ILvLList := []
		AffixList := ["Reinforced","Layered","Lobstered","Buttressed","Thickened","Girded","Impregnable","Impenetrable"]
		ILvLListBodyArmoursShields:= 	[3,17,29,42,60,72,84,86]
		ILvLListAmulets:= 	[2,18,30,42,56,70,77]
		ILvLListGlovesBootsHelmets:= 	[3,17,29,42,60,72,84]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours","Shields"])){
			ILvLList := ILvLListBodyArmoursShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Gloves","Boots"])){
			ILvLList := ILvLListGlovesBootsHelmets
		}else if(indexOf(This.Prop.ItemClass,["Amulets"])){
			ILvLList := ILvLListAmulets
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierIncArmour"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualEvasionTier(){
		AffixName := ["# to Evasion Rating"]
		ILvLList := []
		AffixList := ["Agile","Dancer's","Acrobat's","Fleet","Blurred","Phased","Vaporous","Elusory","Adroit","Lissome","Fugitive"]
		ILvLListBodyArmours:= 	[1,11,17,23,29,35,43,51,60,69,77]
		ILvLListGlovesBoots:= 	[1,11,17,23,29,35,43]
		ILvLListHelmets:= 	[1,11,17,23,29,35,43,51]
		ILvLListShields:= [1,11,17,23,29,35,43,51,60,69]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Shields"])){
			ILvLList := ILvLListShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets"])){
			ILvLList := ILvLListHelmets
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierEvasion"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualIncEvasionTier(){
		AffixName := ["#% increased Evasion Rating"]
		ILvLList := []
		AffixList := ["Shade's","Ghost's","Spectre's","Wraith's","Phantasm's","Nightmare's","Mirage's","Illusion's"]
		ILvLListBodyArmoursShields:= 	[3,17,29,42,60,72,84,86]
		ILvLListHelmetsGlovesBoots:= 	[3,17,29,42,60,72,84]
		ILvLListAmulets:= 	[2,18,30,42,56,70,77]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours","Shields"])){
			ILvLList := ILvLListBodyArmoursShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Gloves","Boots"])){
			ILvLList := ILvLListHelmetsGlovesBoots
		}else if(indexOf(This.Prop.ItemClass,["Amulets"])){
			ILvLList := ILvLListAmulets
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierIncEvasion"] := value
						break
					}
				}
				break
			}
		}
	}	
	GetActualIncArmourEvasionTier(){
		AffixName := ["#% increased Armour and Evasion"]
		ILvLList := []
		AffixList := ["Scrapper's","Brawler's","Fencer's","Gladiator's","Duelist's","Hero's","Legend's","Victor's"]
		ILvLListBodyArmoursShields:= 	[3,17,29,42,60,72,84,86]
		ILvLListHelmetsGlovesBoots:= 	[3,17,29,42,60,72,84]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours","Shields"])){
			ILvLList := ILvLListBodyArmoursShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Gloves","Boots"])){
			ILvLList := ILvLListHelmetsGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierIncArmourEvasion"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualIncArmourESTier(){
		AffixName := ["#% increased Armour and Energy Shield"]
		ILvLList := []
		AffixList := ["Infixed","Ingrained","Instilled","Infused","Inculcated","Interpolated","Inspired","Interpermeated"]
		ILvLListBodyArmoursShields:= 	[3,17,29,42,60,72,84,86]
		ILvLListHelmetsGlovesBoots:= 	[3,17,29,42,60,72,84]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours","Shields"])){
			ILvLList := ILvLListBodyArmoursShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Gloves","Boots"])){
			ILvLList := ILvLListHelmetsGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierIncArmourES"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualIncEvasionESTier(){
		AffixName := ["#% increased Evasion and Energy Shield"]
		ILvLList := []
		AffixList := ["Shadowy","Ethereal","Unworldly","Ephemeral","Evanescent","Unreal","Illusory","Incorporeal"]
		ILvLListBodyArmoursShields:= 	[3,17,29,42,60,72,84,86]
		ILvLListHelmetsGlovesBoots:= 	[3,17,29,42,60,72,84]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours","Shields"])){
			ILvLList := ILvLListBodyArmoursShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Gloves","Boots"])){
			ILvLList := ILvLListHelmetsGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierIncEvasionES"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualEvasionESTier(){
		AffixName := ["(Hybrid) # to Evasion Rating"]
		ILvLList := []
		AffixList := ["Will-o-wisp's","Nymph's","Sylph's","Cherub's","Spirit's","Eidolon's","Apparition's","Phantasm's"]
		ILvLListBodyArmours:= 	[1,18,30,38,46,58,69,79]
		ILvLListShields:= 	[1,18,30,38,46,58,69]
		ILvLListHelmets:= 	[1,18,30,38,46]
		ILvLListGlovesBoots:= 	[1,18,30,38]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Shields"])){
			ILvLList := ILvLListShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets"])){
			ILvLList := ILvLListHelmets
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierEvasionES"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualArmourESTier(){
		AffixName := ["(Hybrid) # to Armour"]
		ILvLList := []
		AffixList := ["Blessed","Anointed","Sanctified","Hallowed","Beatified","Consecrated","Saintly","Godly"]
		ILvLListBodyArmours:= 	[1,18,30,38,46,58,69,79]
		ILvLListShields:= 	[1,18,30,38,46,58,69]
		ILvLListHelmets:= 	[1,18,30,38,46]
		ILvLListGlovesBoots:= 	[1,18,30,38]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Shields"])){
			ILvLList := ILvLListShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets"])){
			ILvLList := ILvLListHelmets
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierArmourES"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualArmourEvasionTier(){
		AffixName := ["(Hybrid) # to Armour"]
		ILvLList := []
		AffixList := ["Supple","Pliant","Flexible","Durable","Sturdy","Resilient","Adaptable","Versatile"]
		ILvLListBodyArmours:= 	[1,18,30,38,46,58,69,79]
		ILvLListShields:= 	[1,18,30,38,46,58,69]
		ILvLListHelmets:= 	[1,18,30,38,46]
		ILvLListGlovesBoots:= 	[1,18,30,38]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Shields"])){
			ILvLList := ILvLListShields
		}else if(indexOf(This.Prop.ItemClass,["Helmets"])){
			ILvLList := ILvLListHelmets
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierArmourEvasion"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualArmourLifeTier(){
		AffixName := ["(Hybrid) # to Armour"]
		ILvLList := []
		AffixList := ["Oyster's","Urchin's","Nautilus's","Crocodile's"]
		ILvLListBodyArmours:= 	[30,46,62,78]
		ILvLListHelmetsShields:= 	[30,46,62]
		ILvLListGlovesBoots:= 	[30,46]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Shields"])){
			ILvLList := ILvLListHelmetsShields
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierArmourLife"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualEvasionLifeTier(){
		AffixName := ["(Hybrid) # to Evasion Rating"]
		ILvLList := []
		AffixList := ["Flea's","Fawn's","Ram's","Ibex's"]
		ILvLListBodyArmours:= 	[30,46,62,78]
		ILvLListHelmetsShields:= 	[30,46,62]
		ILvLListGlovesBoots:= 	[30,46]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Shields"])){
			ILvLList := ILvLListHelmetsShields
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierEvasionLife"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualESLifeTier(){
		AffixName := ["(Hybrid) # to maximum Energy Shield"]
		ILvLList := []
		AffixList := ["Monk's","Prior's","Abbot's","Exarch's"]
		ILvLListBodyArmours:= 	[30,46,62,78]
		ILvLListHelmetsShields:= 	[30,46,62]
		ILvLListGlovesBoots:= 	[30,46]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Shields"])){
			ILvLList := ILvLListHelmetsShields
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierESLife"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualESManaTier(){
		AffixName := ["(Hybrid) # to maximum Energy Shield"]
		ILvLList := []
		AffixList := ["Acolyte's","Deacon's","Priest's","Bishop's"]
		ILvLListBodyArmours:= 	[30,46,62,78]
		ILvLListHelmetsShields:= 	[30,46,62]
		ILvLListGlovesBoots:= 	[30,46]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}
		if(indexOf(This.Prop.ItemClass,["Body Armours"])){
			ILvLList := ILvLListBodyArmours
		}else if(indexOf(This.Prop.ItemClass,["Helmets","Shields"])){
			ILvLList := ILvLListHelmetsShields
		}else if(indexOf(This.Prop.ItemClass,["Gloves","Boots"])){
			ILvLList := ILvLListGlovesBoots
		}
		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierESMana"] := value
						break
					}
				}
				break
			}
		}
	}
	GetActualSpellSuppressTier(){
		AffixName := ["#% chance to Suppress Spell Damage"]
		ILvLList := [46,57,68,76,86]
		AffixList := ["of Rebuttal","of Snuffing","of Revoking","of Abjuration","of Nullification"]

		if(!This.HasModifierFromList(AffixName)){
			Return
		}


		for k,v in ILvLList
		{
			if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
			{
				for ki,vi in AffixList
				{
					If (This.HasAffix(vi)){
						value := k-ki+1
						This.Prop["ActualTierSpellSuppress"] := value
						break
					}
				}
				break
			}
		}

	}
	;Spell Mods
	GetActualDamageModsTier(){
		loop,
		{
			if (A_Index == 1)
			{
				Name:= "INCSpellDamage"
				AffixName:= ["#% increased Spell Damage"]
				ILvLList := [2,11,23,35,46,58,64,84]
				AffixList := ["Apprentice's","Adept's","Scholar's","Professor's","Occultist's","Incanter's","Glyphic","Runic"]
			}else if (A_Index == 2){
				Name:= "INCFireDamage"
				AffixName:= ["#% increased Fire Damage"]
				ILvLList := [2,11,23,35,46,58,64,84]
				AffixList := ["Searing","Sizzling","Blistering","Cauterising","Volcanic","Magmatic","Pyroclastic","Xoph's"]
			}else if (A_Index == 3){
				Name:="INCColdDamage"
				AffixName:= ["#% increased Cold Damage"]
				ILvLList := [2,11,23,35,46,58,64,84]
				AffixList := ["Bitter","Biting","Alpine","Snowy","Hailing","Crystalline","Cryomancer's","Tul's"]
			}else if (A_Index == 4){
				Name:="INCLightningDamage"
				AffixName:= ["#% increased Lightning Damage"]
				ILvLList := [2,11,23,35,46,58,64,84]
				AffixList := ["Charged","Hissing","Bolting","Coursing","Striking","Smiting","Ionising","Esh's"]
			}else if (A_Index == 5){
				Name:="CastSpeed"
				AffixName:= ["#% increased Cast Speed"]
				ILvLList := [2,15,30,40,55,72,83]
				AffixList := ["of Talent","of Nimbleness","of Expertise","of Legerdemain","of Prestidigitation","of Sortilege","of Finesse"]
				ILvLListRings := [2]
				ILvLListAmulets := [2,15,30]
				if(indexOf(This.Prop.ItemClass,["Amulets"])){
					ILvLList := ILvLListAmulets
				}
				else if(indexOf(This.Prop.ItemClass,["Rings"])){
					ILvLList := ILvLListRings
				}
			}else if (A_Index == 6){
				Name:="ChaosDOT"
				AffixName:= ["#% to Chaos Damage over Time Multiplier"]
				ILvLList := [4,12,36,64,78]
				AffixList := ["of Waning","of Wasting","of Deteriorating","of Atrophying","of Disintegrating"]
			}else if (A_Index == 7){
				Name:="ColdDOT"
				AffixName:= ["#% to Cold Damage over Time Multiplier"]
				ILvLList := [4,12,36,64,78]
				AffixList := ["of the Inclement","of the Bleak","of the Boreal","of the Gelid","of Heartstopping"]
			}else if (A_Index == 8){
				Name:="FireDOT"
				AffixName:= ["#% to Fire Damage over Time Multiplier"]
				ILvLList := [4,12,36,64,78]
				AffixList := ["of the Earnest","of the Fervid","of the Ardent","of the Zealous","of the Fanatical"]
			}else if (A_Index == 9){
				Name:="PhysicalDOT"
				AffixName:= ["#% to Physical Damage over Time Multiplier"]
				ILvLList := [4,12,36,64,78]
				AffixList := ["of Seeping","of Spilling","of Phlebotomising","of Hemorrhaging","of Exsanguinating"]
			}else if (A_Index == 10){
				Name:="DOTMultiplier"
				AffixName:= ["#% to Damage over Time Multiplier","#% to Damage over Time Multiplier with Attack Skills"]
				ILvLList := [44,55,68,76,82]
				AffixList := ["of Acrimony","of Dispersion","of Liquefaction","of Melting","of Dissolution"]
			}else if (A_Index == 11){
				Name:="GlobalCriticalStrikeMultiplier"
				AffixName := ["#% to Global Critical Strike Multiplier","#% to Critical Strike Multiplier with Bows"]
				ILvLList := [8,21,30,44,59,73]
				AffixList := ["of Ire","of Anger","of Rage","of Fury","of Ferocity","of Destruction"]
				ILvLListAmulets := [8,21,31,45,59,74]
				if(indexOf(This.Prop.ItemClass,["Amulets"])){
					ILvLList := ILvLListAmulets
				}
			}else if (A_Index == 12){
				Name:="CriticalStrikeChance"
				AffixName := ["#% increased Critical Strike Chance","#% increased Critical Strike Chance with Bows","#% increased Global Critical Strike Chance"]
				ILvLList := [1,20,30,44,59,73]
				AffixList := ["of Needling","of Stinging","of Piercing","of Puncturing","of Penetrating","of Incision","of Rending"]
				ILvLListAmulets := [5,20,30,44,58,72]
				ILvLListQuivers := [5,20,30,44,58,72,85]
				if(indexOf(This.Prop.ItemClass,["Amulets"])){
					ILvLList := ILvLListAmulets
				}else if(indexOf(This.Prop.ItemClass,["Quivers"])){
					ILvLList := ILvLListQuivers
				}
			}else if (A_Index == 13){
				Name:="AttackSpeed"
				AffixName := ["#% increased Attack Speed"]
				ILvLList := [1,11,22,30,37,45,60,77]
				AffixList := ["of Skill","of Ease","of Mastery","of Renown","of Acclaim","of Fame","of Infamy","of Celebration"]
				ILvLListGloves := 	[1,11,22,76]
				ILvLListQuiversShields := 	[1,11,22]
				ILvLListRings := 	[1]
				ILvLListWandsBows := 	[1,11,22,30,37]
				if(indexOf(This.Prop.ItemClass,["Gloves"])){
					ILvLList := ILvLListGloves
					;Special Case for Gloves
					if(This.HasAffix("of Grandmastery"){
						This.Prop["ActualTier"Name] := 1
						Continue
					}
				}else if(indexOf(This.Prop.ItemClass,["Quiver","Shields"])){
					ILvLList := ILvLListQuiversShields
				}else if(indexOf(This.Prop.ItemClass,["Rings"])){
					ILvLList := ILvLListRings
				}else if(indexOf(This.Prop.ItemClass,["Wands","Bows"])){
					ILvLList := ILvLListWandsBows
				}
			}else if (A_Index == 14){
				Name:="IncElementalDamage"
				AffixName := ["#% increased Elemental Damage with Attack Skills"]
				ILvLList := [4,15,30,60,81,86]
				AffixList := ["Catalysing","Infusing","Empowering","Unleashed","Overpowering","Devastating"]
				ILvLListRings := [4,15,30,60,81]
				if(indexOf(This.Prop.ItemClass,["Rings"])){
					ILvLList := ILvLListRings
				}
			}else if (A_Index == 15){
				Name:="AddLightningDamage"
				AffixName := ["Adds # to # Lightning Damage","Adds # to # Lightning Damage to Attacks"]
				ILvLList := [3,13,19,31,34,42,51,63,74,82]
				AffixList := ["Humming","Buzzing","Snapping","Crackling","Sparking","Arcing","Shocking","Discharging","Electrocuting","Vapourising"]
				ILvLListAmuletsRingsQuivers := [3,13,22,28,35,44,52,64,76]
				if(indexOf(This.Prop.ItemClass,["Amulets","Rings","Quivers"])){
					ILvLList := ILvLListAmuletsRingsQuivers
				}
			}else if (A_Index == 16){
				Name:="AddColdDamage"
				AffixName := ["Adds # to # Cold Damage","Adds # to # Cold Damage to Attacks"]
				ILvLList := [2,12,19,27,34,43,52,63,75,82]
				AffixList := ["Frosted","Chilled","Icy","Frigid","Freezing","Frozen","Glaciated","Polar","Entombing","Crystalising"]
				ILvLListAmuletsRingsQuivers := [2,13,21,29,36,45,53,65,77]
				if(indexOf(This.Prop.ItemClass,["Amulets","Rings","Quivers"])){
					ILvLList := ILvLListAmuletsRingsQuivers
				}
			}else if (A_Index == 17){
				Name:="AddFireDamage"
				AffixName := ["Adds # to # Fire Damage","Adds # to # Fire Damage to Attacks"]
				ILvLList := [1,11,18,26,33,42,51,62,74,82]
				AffixList := ["Heated","Smouldering","Smoking","Burning","Flaming","Scorching","Incinerating","Blasting","Cremating","Carbonising"]
				ILvLListAmuletsRingsQuivers := [1,12,20,28,35,44,52,64,76]
				if(indexOf(This.Prop.ItemClass,["Amulets","Rings","Quivers"])){
					ILvLList := ILvLListAmuletsRingsQuivers
				}
			}else if (A_Index == 18){
				Name:="AddPhysicalDamage"
				AffixName := ["Adds # to # Physical Damage","Adds # to # Physical Damage to Attacks"]
				ILvLList := [1,11,23,35,46,60,73,83]
				AffixList := ["Glinting","Burnished","Polished","Honed","Gleaming","Annealed","Razor-sharp","Tempered","Flaring"]
				ILvLListRings := [5,13,19,28,35,44]
				ILvLListAmuletsQuivers := [5,13,19.28,35,44,52,64,76]
				if(indexOf(This.Prop.ItemClass,["Rings"])){
					ILvLList := ILvLListRings
				}else if(indexOf(This.Prop.ItemClass,["Amulets","Quivers"])){
					ILvLList := ILvLListAmuletsQuivers
				}
			}else if (A_Index == 19){
				Name:="IncPhysicalDamage"
				AffixName := ["#% increased Physical Damage"]
				ILvLList := [1,11,23,35,46,60,73,83]
				AffixList := ["Heavy","Serrated","Wicked","Vicious","Bloodthirsty","Cruel","Tyrannical","Merciless"]
				;Incursion Mod
				If (This.HasAffix("Tacati's") && This.Affix["#% increased Physical Damage"]){
					This.Prop["ActualTier"Name] := := 1
					return
				}
			}else if (A_Index == 20){
				Name:="Accuracy"
				AffixName := ["# to Accuracy Rating"]
				ILvLList := [1,20,40,60,75]
				AffixList := ["of Steadiness","of Precision","of the Sniper","of the Marksman","of the Ranger","of Lioneye"]
				ILvLListWandsHelmetsGloves := 	[1,20,40,60,75,85]
				if(indexOf(This.Prop.ItemClass,["Gloves","Helmets","Wands"])){
					ILvLList := ILvLListWandsHelmetsGloves
				}
			}else{
				Break
			}

			if(!This.HasModifierFromList(AffixName)){
				Continue
			}

			for k,v in ILvLList
			{
				if ((This.Prop.ItemLevel >= v && This.Prop.ItemLevel < ILvLList[k+1]) || k == ILvLList.Length())
				{
					for ki,vi in AffixList
					{
						If (This.HasAffix(vi)){
							value := k-ki+1
							This.Prop["ActualTier"Name] := value
							break
						}
					}
					break
				}
			}
		}
	}
	HasModifierFromList(ModList){
		for k,v in ModList{
			if (This.Affix[v]){
				return true
			}
		}
		return false
	}
	HasAffix(Name){
		local Type, Obj, k, v
		For Type, Obj in This.Data.AffixNames {
			For k, v in Obj {
				If (v.Name = Name)
					Return True
			}
		}
		Return False
	}
	MatchBase2Slot(){
		If (This.Prop.ItemClass ~= "Body Armour")
			This.Prop.SlotType := "Body"
		Else If (This.Prop.ItemClass ~= "Helmet")
			This.Prop.SlotType := "Helmet"
		Else If (This.Prop.ItemClass ~= "Glove")
			This.Prop.SlotType := "Gloves"
		Else If (This.Prop.ItemClass ~= "Boot")
			This.Prop.SlotType := "Boots"
		Else If (This.Prop.ItemClass ~= "Belt")
			This.Prop.SlotType := "Belt"
		Else If (This.Prop.ItemClass ~= "Amulet")
			This.Prop.SlotType := "Amulet"
		Else If (This.Prop.ItemClass ~= "Ring")
			This.Prop.SlotType := "Ring"
		Else If (This.Prop.ItemClass ~= "(One|Wand|Dagger|Sceptre|Claw)")
			This.Prop.SlotType := "One Hand"
		Else If (This.Prop.ItemClass ~= "(Two|Bow|stave|Staff)")
			This.Prop.SlotType := "Two Hand"
		Else If (This.Prop.ItemClass ~= "Shield")
			This.Prop.SlotType := "Shield"
	}
	MatchChaosRegal(){
		If (This.Prop.Rarity_Digit = 3 && This.Prop.SlotType != "" )
		{
			If (This.Prop.ItemLevel >= 60 && This.Prop.ItemLevel <= 74 && (ChaosRecipeTypePure || ChaosRecipeTypeHybrid))
				This.Prop.ChaosRecipe := 1
			Else If (This.Prop.ItemLevel >= 75 && This.Prop.ItemLevel <= 100 && (ChaosRecipeTypeRegal || ChaosRecipeTypeHybrid))
				This.Prop.RegalRecipe := 1
		}
	}
	StashChaosRecipe(deposit:=false){
		Global RecipeArray
		Static TypeList := [ "Amulet", "Ring", "Belt", "Boots", "Gloves", "Helmet", "Body" ]
		Static WeaponList := [ "One Hand", "Two Hand", "Shield" ]
		If ( This.Prop.Rarity_Digit != 3 )
		|| ( This.Prop.ItemLevel < 60 )
		|| !( This.Prop.SlotType )
		|| ( ChaosRecipeTypePure && This.Prop.ItemLevel > 74)
		|| ( ChaosRecipeTypeRegal && This.Prop.ItemLevel < 75 )
		|| ( ChaosRecipeSmallWeapons && (This.Prop.IsWeapon || This.Prop.ItemClass = "Shields") 
			&& (( This.Prop.Item_Width > 1 && This.Prop.Item_Height > 2) || ( This.Prop.Item_Width = 1 && This.Prop.Item_Height > 3)) 
			&& !(This.Prop.IsTwoHanded && This.Prop.Item_Width = 2 && This.Prop.Item_Height = 3) )
			Return False
		If (ChaosRecipeSkipJC && (This.Prop.Jeweler || This.Prop.Chromatic))
			Return False
		If !IsObject(RecipeArray)
		{
			If !ChaosRecipe(1)
			{
				Notify("Error","Requesting stash information Failed`nCheck your POESESSID",3)
				Return False
			}
		}
		For k, v in TypeList
		{
			If (This.Prop.SlotType = v)
			{
				If This.Affix.Unidentified {
					CountValue := retCount(RecipeArray.uChaos[v]) + retCount(RecipeArray.uRegal[v])
					ChaosRecipeMaxHolding := ChaosRecipeMaxHoldingUNID
				} Else {
					CountValue := retCount(RecipeArray.Chaos[v]) + retCount(RecipeArray.Regal[v])
					ChaosRecipeMaxHolding := ChaosRecipeMaxHoldingID
				}
				If (v = "Ring")
					CountValue := CountValue / 2
				If (ChaosRecipeAllowDoubleJewellery && IndexOf(v,["Ring","Amulet"]))
					CountValue := CountValue / 2
				If (ChaosRecipeAllowDoubleBelt && IndexOf(v,["Belt"]))
					CountValue := CountValue / 2

				If (CountValue < ChaosRecipeMaxHolding)
				{
					If (OnStash && deposit)
					{
						If This.Affix.Unidentified
						{
							If This.Prop.ChaosRecipe
								RecipeArray.uChaos[v].Push(This)
							Else If This.Prop.RegalRecipe
								RecipeArray.uRegal[v].Push(This)
							Else
								Return False
						} Else {
							If This.Prop.ChaosRecipe
								RecipeArray.Chaos[v].Push(This)
							Else If This.Prop.RegalRecipe
								RecipeArray.Regal[v].Push(This)
							Else
								Return False
						}
					}
					Return True
				}
				Else
					Return False
			}
		}
		For k, v in WeaponList
		{
			If (This.Prop.SlotType = v)
			{
				If This.Affix.Unidentified{
					WeaponCount := retCount(RecipeArray.uRegal["Two Hand"]) + retCount(RecipeArray.uChaos["Two Hand"]) 
					WeaponCount += (retCount(RecipeArray.uRegal["One Hand"]) + retCount(RecipeArray.uChaos["One Hand"])) / 2
					WeaponCount += (retCount(RecipeArray.uRegal["Shield"]) + retCount(RecipeArray.uChaos["Shield"])) / 2
					ChaosRecipeMaxHolding := ChaosRecipeMaxHoldingUNID
				}Else{
					WeaponCount := retCount(RecipeArray.Regal["Two Hand"]) + retCount(RecipeArray.Chaos["Two Hand"]) 
					WeaponCount += (retCount(RecipeArray.Regal["One Hand"]) + retCount(RecipeArray.Chaos["One Hand"])) / 2 
					WeaponCount += (retCount(RecipeArray.Regal["Shield"]) + retCount(RecipeArray.Chaos["Shield"])) / 2
					ChaosRecipeMaxHolding := ChaosRecipeMaxHoldingID
				}
				If (WeaponCount < ChaosRecipeMaxHolding)
				{
					If (OnStash && deposit)
					{
						If This.Affix.Unidentified
						{
							If This.Prop.ChaosRecipe
								RecipeArray.uChaos[v].Push(This)
							Else If This.Prop.RegalRecipe
								RecipeArray.uRegal[v].Push(This)
						} Else {
							If This.Prop.ChaosRecipe
								RecipeArray.Chaos[v].Push(This)
							Else If This.Prop.RegalRecipe
								RecipeArray.Regal[v].Push(This)
						}
					}
					Return True
				}
				Else
					Return "000"
			}
		}
		Return False
	}
	MatchAffixesWithoutDoubleMods(content:=""){
		; These lines remove the extra line created by "additional information bubbles"
		If (content ~= "\n\(")
			content := RegExReplace(content, "\n\(", "(")
		content := RegExReplace(content,"\(\w+ \w+ [\w\d\.% ,'\+\-]+\)", "")
		; Do Stuff with info
		LastLine := ""
		DoubleModCounter := 0
		Loop, Parse,% content, `r`n  ; , `r
		{
			If (A_LoopField = "" || A_LoopField ~= "^\{ .* \}$")
			{
				DoubleModCounter := 0
				Continue
			}
			DoubleModCounter++
			if(DoubleModCounter == 2){
				If (vals := This.MatchLine(LastLine))
				{

					If (vals.Count() == 1 && This.CheckIfActualHybridMod(key))
					{
						If This.Affix[key]
						{
							This.Affix[key] -= vals[1]
							This.AddHybridModAffix(key,vals[1])
						}
						Else{
							This.AddHybridModAffix(key,vals[1])
						}
					}Else
					{
						DoubleModCounter := 0
					}
				}
			}
			line :=  RegExReplace(A_LoopField, rxNum "\(" rxNum "-" rxNum "\)", "$1")
			line :=  RegExReplace(line, rxNum "\(-" rxNum "--" rxNum "\)", "$1")
			line :=  RegExReplace(line,  " . Unscalable Value" , "")
			;Fix Extra Text from Spell Suppress Mods
			line :=  RegExReplace(line,  "\(50% of Damage from Suppressed Hits and Ailments they inflict is prevented\)" , "")
			key := This.Standardize(line)
			If (vals := This.MatchLine(line))
			{
				If (vals.Count() >= 2)
				{
					If (line ~= rxNum " to " rxNum || line ~= rxNum "-" rxNum)
						This.Affix[key] := (Format("{1:0.3g}",(vals[1] + vals[2]) / 2))
					Else
						This.Affix[key] := vals[1]
					For k, v in vals
						This.Affix[ key "_value"k ] := v
				}
				Else If (vals.Count() == 1)
				{
					If (This.Affix[key] && DoubleModCounter != 2)
					{
						This.Affix[key] += vals[1]
					}Else If(DoubleModCounter != 2){
						This.Affix[key] := vals[1]
					}Else{
						This.AddHybridModAffix(key,vals[1])
					}
				}
			}
			Else
				This.Affix[key] := True
			LastLine := line

			If (A_LoopField ~= rxNum "\(-*" rxNum "-*" rxNum "\)") {
				EndValue := 0
				Position := 1
				While RegExMatch(A_LoopField, "O`am)" rxNum "\(-*" rxNum "-*" rxNum "\)", RxMatch, Position) {
					Position := RxMatch.Len(0) + RxMatch.Pos(0)
					Value := RxMatch.Value(1)
					Range1 := RxMatch.Value(2)
					Range2 := RxMatch.Value(3)
					Perc := This.perc(Value,[Range1,Range2])
					EndEntries := A_Index
					EndValue += Perc
				}
				EndValue := EndValue / EndEntries
				If !This.Percent.HasKey(Key)
					This.Percent[key] := EndValue
				Else {
					Loop {
						If !This.Percent.HasKey(Key A_Index + 1){
							This.Percent[Key A_Index + 1] := EndValue
							Break
						}
					}
				}
			}
		}
		If This.Percent.Count() {
			This.Prop.PercentageAffix := 0
			For mod, val in This.Percent {
				This.Prop.PercentageAffix += val
			}
			This.Prop.PercentageAffix := Round(This.Prop.PercentageAffix / This.Percent.Count(),2)
		} Else {
			This.Prop.PercentageAffix := 100
		}
	}
	CheckIfActualHybridMod(value){
		for k, v in HybridModsFirstLine
		{
				if (v == value)
				{
					return true
				}
		}
		return false
	}
	AddHybridModAffix(Key,Value){
		HybridKey := "(Hybrid) " . Key
		If(!This.Affix[HybridKey])
		{
			aux := Value
			If  (aux != 0)
				This.Affix[HybridKey] := aux
		}Else
		{
			aux := This.GetValue("Affix", HybridKey) + Value
			If  (aux != 0)
				This.Affix[HybridKey] := aux
		}
		return
	}
	MatchAffixes(content:=""){
		; These lines remove the extra line created by "additional information bubbles"
		If (content ~= "\n\(")
			content := RegExReplace(content, "\n\(", "(")
		content := RegExReplace(content," ?\(\w+ \w+ [\r\n\w\%\d,\: ]*\)( \(enchant\))?", "")
		; Do Stuff with info
		Loop, Parse,% content, `r`n  ; , `r
		{
			If (A_LoopField = "" || A_LoopField ~= "^\{ .* \}$")
				Continue
			line :=  RegExReplace(A_LoopField, rxNum "\(" rxNum "-" rxNum "\)", "$1")
			line :=  RegExReplace(line, rxNum "\(-" rxNum "--" rxNum "\)", "$1")
			line :=  RegExReplace(line,  " . Unscalable Value" , "")
			key := This.Standardize(line)
			If (key ~= "^ \(.*\)$")
				Continue
			If (vals := This.MatchLine(line))
			{
				If (vals.Count() >= 2)
				{
					If (line ~= rxNum " to " rxNum || line ~= rxNum "-" rxNum)
						This.Affix[key] := (Format("{1:0.3g}",(vals[1] + vals[2]) / 2))
					Else
						This.Affix[key] := vals[1]
					For k, v in vals
						This.Affix[ key "_value"k ] := v
				}
				Else If (vals.Count() == 1)
				{
					If This.Affix[key]
						This.Affix[key] += vals[1]
					Else
						This.Affix[key] := vals[1]
				}
			}
			Else
				This.Affix[key] := True
		}
	}
	MatchLine(lineString){
		If (RegExMatch(lineString, "O`am)" rxNum "[ \-a-zA-Z+,\%]{0,}+" rxNum "{0,}[ \-a-zA-Z+,\%]{0,}+" rxNum "{0,}[ \-a-zA-Z+,\%]{0,}+" rxNum "{0,}[ \-a-zA-Z+,\%]{0,}+" , RxMatch))
		{
			ret := {}
			Loop % RxMatch.Count()
			{
				If RxMatch[A_Index] != ""
					ret.push(RxMatch[A_Index])
			}
			Return ret
		}
		Else
			Return False
	}
	Standardize(str:=""){
		str := RegExReplace(str, "\+?"rxNum , "#")
		; str := RegExReplace(str, "#\(#-#\)" , "#")
		str := RegExReplace(str, " (augmented)" , "")
		Return str
	}
	MatchPseudoAffix(){
		for k, v in This.Affix
		{
			; Standardize implicit and crafted for Pseudo sums
			; Implicits can be disable being merge into Pseudos checking YesCLFIgnoreImplicit
			If (RegExMatch(k, "`am) \((.*)\)$", RxMatch) && YesCLFIgnoreImplicit)	
			{
				If (RxMatch1 != "crafted")
				{
					Continue
				}
			}
			trimKey := RegExReplace(k," \(.*\)$","")
			; Singular Resistances
			If (trimKey = "# to maximum Life")
			{
				This.AddPseudoAffix("(Pseudo) Total to Maximum Life",k)
			}
			If (trimKey = "#% to Cold Resistance")
			{
				This.AddPseudoAffix("(Pseudo) Total to Cold Resistance",k)
			}
			Else If (trimKey = "#% to Fire Resistance")
			{
				This.AddPseudoAffix("(Pseudo) Total to Fire Resistance",k)
			}
			Else If (trimKey = "#% to Lightning Resistance")
			{
				This.AddPseudoAffix("(Pseudo) Total to Lightning Resistance",k)
			}
			Else If (trimKey = "#% to Chaos Resistance")
			{
				This.AddPseudoAffix("(Pseudo) Total to Chaos Resistance",k)
			}
			; Double Resistances
			Else If (trimKey = "#% to Cold and Lightning Resistances")
			{
				This.AddPseudoAffix("(Pseudo) Total to Cold Resistance",k)
				This.AddPseudoAffix("(Pseudo) Total to Lightning Resistance",k)
			}
			Else If (trimKey = "#% to Fire and Cold Resistances")
			{
				This.AddPseudoAffix("(Pseudo) Total to Fire Resistance",k)
				This.AddPseudoAffix("(Pseudo) Total to Cold Resistance",k)
			}
			Else If (trimKey = "#% to Fire and Lightning Resistances")
			{
				This.AddPseudoAffix("(Pseudo) Total to Fire Resistance",k)
				This.AddPseudoAffix("(Pseudo) Total to Lightning Resistance",k)
			}
			; All Resistances
			Else If (trimKey = "#% to all Elemental Resistances")
			{
				This.AddPseudoAffix("(Pseudo) Total to Fire Resistance",k)
				This.AddPseudoAffix("(Pseudo) Total to Lightning Resistance",k)
				This.AddPseudoAffix("(Pseudo) Total to Cold Resistance",k)
			}
			; Attributes Singular
			Else If (trimKey = "# to Intelligence")
			{
				This.AddPseudoAffix("(Pseudo) Total to Intelligence",k)
			}
			Else If (trimKey = "# to Dexterity")
			{
				This.AddPseudoAffix("(Pseudo) Total to Dexterity",k)
			}
			Else If (trimKey = "# to Strength")
			{
				This.AddPseudoAffix("(Pseudo) Total to Strength",k)
			}
			; Double Atributes
			Else If (trimKey = "# to Strength and Dexterity")
			{
				This.AddPseudoAffix("(Pseudo) Total to Strength",k)
				This.AddPseudoAffix("(Pseudo) Total to Dexterity",k)
			}
			Else If (trimKey = "# to Dexterity and Intelligence")
			{
				This.AddPseudoAffix("(Pseudo) Total to Dexterity",k)
				This.AddPseudoAffix("(Pseudo) Total to Intelligence",k)
			}
			Else If (trimKey = "# to Strength and Intelligence")
			{
				This.AddPseudoAffix("(Pseudo) Total to Strength",k)
				This.AddPseudoAffix("(Pseudo) Total to Intelligence",k)
			}
			; All Atribbutes
			Else If (trimKey = "# to all Attributes")
			{
				This.AddPseudoAffix("(Pseudo) Total to Strength",k)
				This.AddPseudoAffix("(Pseudo) Total to Intelligence",k)
				This.AddPseudoAffix("(Pseudo) Total to Dexterity",k)
			}
			; Singular Armour Affix
			Else If (trimKey = "#% increased Armour")
			{
				This.AddPseudoAffix("(Pseudo) Total Increased Armour",k)
			}
			Else If (trimKey = "#% increased Evasion Rating")
			{
				This.AddPseudoAffix("(Pseudo) Total Increased Evasion",k)
			}
			Else If (trimKey = "#% increased Energy Shield")
			{
				This.AddPseudoAffix("(Pseudo) Total Increased Energy Shield",k)
			}
			Else If (trimKey = "#% to maximum Energy Shield")
			{
				This.AddPseudoAffix("(Pseudo) Total to Maximum Energy Shield",k)
			}
			; Double Armour Affix
			Else If (trimKey = "#% increased Evasion and Energy Shield")
			{
				This.AddPseudoAffix("(Pseudo) Total Increased Evasion",k)
				This.AddPseudoAffix("(Pseudo) Total Increased Energy Shield",k)
			}
			Else If (trimKey = "#% increased Armour and Energy Shield")
			{
				This.AddPseudoAffix("(Pseudo) Total Increased Armour",k)
				This.AddPseudoAffix("(Pseudo) Total Increased Energy Shield",k) 
			}
			Else If (trimKey = "#% increased Armour and Evasion")
			{
				This.AddPseudoAffix("(Pseudo) Total Increased Armour",k)
				This.AddPseudoAffix("(Pseudo) Total Increased Evasion",k)
			}
			; Damage Mods
			Else If (trimKey = "Adds # to # Physical Damage to Attacks")
			{
				This.AddPseudoAffix("(Pseudo) Add Physical Damage to Attacks",k)
			}
			Else If (trimKey = "Adds # to # Physical Damage to Spells")
			{
				This.AddPseudoAffix("(Pseudo) Add Physical Damage to Spells",k)
			}
			Else If (trimKey = "Adds # to # Cold Damage to Attacks")
			{
				This.AddPseudoAffix("(Pseudo) Add Cold Damage to Attacks",k)
			}
			Else If (trimKey = "Adds # to # Cold Damage to Spells")
			{
				This.AddPseudoAffix("(Pseudo) Add Cold Damage to Spells",k)
			}
			Else If (trimKey = "Adds # to # Fire Damage to Attacks")
			{
				This.AddPseudoAffix("(Pseudo) Add Fire Damage to Attacks",k)
			}
			Else If (trimKey = "Adds # to # Fire Damage to Spells")
			{
				This.AddPseudoAffix("(Pseudo) Add Fire Damage to Spells",k)
			}
			Else If (trimKey = "Adds # to # Lightning Damage to Attacks")
			{
				This.AddPseudoAffix("(Pseudo) Add Lightning Damage to Attacks",k)
			}
			Else If (trimKey = "Adds # to # Lightning Damage to Spells")
			{
				This.AddPseudoAffix("(Pseudo) Add Lightning Damage to Spells",k)
			}
			Else If (trimKey = "Adds # to # Chaos Damage to Attacks")
			{
				This.AddPseudoAffix("(Pseudo) Add Chaos Damage to Attacks",k)
			}
			Else If (trimKey = "Adds # to # Chaos Damage to Spells")
			{
				This.AddPseudoAffix("(Pseudo) Add Chaos Damage to Spells",k)
			}
			; Spell Pseudo
			Else If (trimKey = "#% increased Lightning Damage")
			{
				This.AddPseudoAffix("(Pseudo) Increased Lightning Damage",k)
			}
			Else If (trimKey = "#% increased Cold Damage")
			{
				This.AddPseudoAffix("(Pseudo) Increased Cold Damage",k)
			}
			Else If (trimKey = "#% increased Fire Damage")
			{
				This.AddPseudoAffix("(Pseudo) Increased Fire Damage",k)
			}
			Else If (trimKey = "#% increased Chaos Damage")
			{
				This.AddPseudoAffix("(Pseudo) Increased Chaos Damage",k)
			}
			Else If (trimKey = "#% increased Spell Damage")
			{
				This.AddPseudoAffix("(Pseudo) Increased Lightning Damage",k)
				This.AddPseudoAffix("(Pseudo) Increased Cold Damage",k)
				This.AddPseudoAffix("(Pseudo) Increased Fire Damage",k)
				This.AddPseudoAffix("(Pseudo) Increased Chaos Damage",k)
				This.AddPseudoAffix("(Pseudo) Increased Spell Damage",k)
			}
			Else If (trimKey = "#% increased Elemental Damage")
			{
				This.AddPseudoAffix("(Pseudo) Increased Lightning Damage",k)
				This.AddPseudoAffix("(Pseudo) Increased Cold Damage",k)
				This.AddPseudoAffix("(Pseudo) Increased Fire Damage",k)
			}
		}
		; SUM Pseudo
		; Total Elemental Resistance
		This.AddPseudoAffix("(Pseudo) Total to Elemental Resistance","(Pseudo) Total to Fire Resistance","Pseudo")
		This.AddPseudoAffix("(Pseudo) Total to Elemental Resistance","(Pseudo) Total to Lightning Resistance","Pseudo")
		This.AddPseudoAffix("(Pseudo) Total to Elemental Resistance","(Pseudo) Total to Cold Resistance","Pseudo")

		; Total Resistance
		This.AddPseudoAffix("(Pseudo) Total to Resistance","(Pseudo) Total to Elemental Resistance","Pseudo")
		This.AddPseudoAffix("(Pseudo) Total to Resistance","(Pseudo) Total to Chaos Resistance","Pseudo")
		aux := 0
		If (This.GetValue("Pseudo","(Pseudo) Total to Fire Resistance") > aux)
			aux := This.GetValue("Pseudo","(Pseudo) Total to Fire Resistance")
		If (This.GetValue("Pseudo","(Pseudo) Total to Cold Resistance") > aux)
			aux := This.GetValue("Pseudo","(Pseudo) Total to Cold Resistance")
		If (This.GetValue("Pseudo","(Pseudo) Total to Lightning Resistance") > aux)
			aux := This.GetValue("Pseudo","(Pseudo) Total to Lightning Resistance")
		If (This.GetValue("Pseudo","(Pseudo) Total to Chaos Resistance") > aux)
			aux := This.GetValue("Pseudo","(Pseudo) Total to Chaos Resistance")
		If(aux > 0)
		{
			This.Pseudo["(Pseudo) Total to Single Resistance"] := aux
		}

		; Total Stats
		This.AddPseudoAffix("(Pseudo) Total to Stats","(Pseudo) Total to Strength","Pseudo")
		This.AddPseudoAffix("(Pseudo) Total to Stats","(Pseudo) Total to Intelligence","Pseudo")
		This.AddPseudoAffix("(Pseudo) Total to Stats","(Pseudo) Total to Dexterity","Pseudo")
		; Maximum Life
		aux:= This.GetValue("Pseudo","(Pseudo) Total to Maximum Life")
		+ (This.GetValue("Pseudo","(Pseudo) Total to Strength"))//2
		If(aux > 0)
		{
			This.Pseudo["(Pseudo) Total to Maximum Life"] := aux
		}
		aux:=""
		; Total Flat Elemental Spell Damage
		This.AddPseudoAffix("(Pseudo) Total Elemental Damage to Spells","(Pseudo) Add Cold Damage to Spells","Pseudo")
		This.AddPseudoAffix("(Pseudo) Total Elemental Damage to Spells","(Pseudo) Add Fire Damage to Spells","Pseudo")
		This.AddPseudoAffix("(Pseudo) Total Elemental Damage to Spells","(Pseudo) Add Lightning Damage to Spells","Pseudo")
		; Total Flat Elemental Atack Dmg
		This.AddPseudoAffix("(Pseudo) Total Elemental Damage to Attacks","(Pseudo) Add Cold Damage to Attacks","Pseudo")
		This.AddPseudoAffix("(Pseudo) Total Elemental Damage to Attacks","(Pseudo) Add Fire Damage to Attacks","Pseudo")
		This.AddPseudoAffix("(Pseudo) Total Elemental Damage to Attacks","(Pseudo) Add Lightning Damage to Attacks","Pseudo")
		; Merge
		This.MergePseudoInAffixs()
	}
	GetValue(Type, Context){
		If !This[Type][Context]
		{
			return 0
		}
		Else
		{
			return This[Type][Context]
		}
	}
	AddPseudoAffix(PseudoKey,StandardKey,StandardType:="Affix"){
		HybridKey := "(Hybrid) " . StandardKey
		aux := This.GetValue("Pseudo", PseudoKey) + This.GetValue("Affix", HybridKey) + This.GetValue(StandardType, StandardKey)
		If  (aux != 0)
			This.Pseudo[PseudoKey] := aux
		return
	}
	MergePseudoInAffixs(){
		for k, v in This.Pseudo
		{
			This.Affix[k] := v
		}
		; Free Object (Not needed)
		This.Pseudo := ""
		This.Delete("Pseudo")
	}
	FuckingSugoiFreeMate(){
		This.Data := ""
		This.Delete("Data")
	}
	MatchExtenalDB(){
		For k, v in QuestItems
		{
			If (v["Name"] = This.Prop.ItemName)
			{
				This.Prop.Item_Width := v["Width"]
				This.Prop.Item_Height := v["Height"]
				This.Prop.SpecialType := "Quest Item"
				Return
			}
		}
		If (!This.Prop.IsMap)
		{
			For k, v in Bases
			{
				If (v["name"] = This.Prop.ItemBase)
				{
					This.Prop.Item_Width := v["inventory_width"]
					This.Prop.Item_Height := v["inventory_height"]
					This.Prop.ItemBase := v["name"]
					This.Prop.DropLevel := v["drop_level"]


					If (This.Prop.Rating_Armour || This.Prop.Rating_EnergyShield || This.Prop.Rating_Evasion){
						tally := total := 0
						If This.Prop.Rating_Armour {
							tally++
							val := This.Perc(This.Prop.Rating_Armour,[v.properties.armour.min,v.properties.armour.max])
							total += val
							This.Prop.Rating_Armour_Percent := round(val,2)
						}
						If This.Prop.Rating_EnergyShield {
							tally++
							val := This.Perc(This.Prop.Rating_EnergyShield,[v.properties.energy_shield.min,v.properties.energy_shield.max])
							total += val
							This.Prop.Rating_EnergyShield_Percent := round(val,2)
						}
						If This.Prop.Rating_Evasion {
							tally++
							val := This.Perc(This.Prop.Rating_Evasion,[v.properties.evasion.min,v.properties.evasion.max])
							total += val
							This.Prop.Rating_Evasion_Percent := round(val,2)
						}
						This.Prop.Rating_Percent := round(total/tally,2)
						tally := total := val := ""
					}

					If InStr(This.Prop.ItemClass, "Rings")
						This.Prop.Ring := True
					If InStr(This.Prop.ItemClass, "Amulets")
						This.Prop.Amulet := True
					If InStr(This.Prop.ItemClass, "Belts")
						This.Prop.Belt := True
					If (This.Prop.ItemClass = "Support Skill Gems")
						This.Prop.Support := True
					Break
				}
			}
		}
		;Start Ninja DB Matching
		If (This.Prop.RarityCurrency)
		{
			If (This.Prop.ItemName ~= "Delirium Orb")
			{
				If This.MatchNinjaDB("DeliriumOrb")
					Return
			}
			If (This.Prop.ItemName ~= "Vial of")
			{
				If This.MatchNinjaDB("Vial")
					Return
			}
			Else If (This.Prop.ItemName ~= "Essence of")
			{
				If This.MatchNinjaDB("Essence")
					Return
			}
			Else If (This.Prop.Incubator )
			{
				If This.MatchNinjaDB("Incubator")
					Return
			}
			Else If (This.Prop.Oil )
			{
				If This.MatchNinjaDB("Oil")
					Return
			}
			Else If (This.Prop.ItemName ~= "Fossil" )
			{
				If This.MatchNinjaDB("Fossil")
					Return
			}
			Else If (This.Prop.ItemName ~= "Resonator" )
			{
				If This.MatchNinjaDB("Resonator")
					Return
			}
			If This.MatchNinjaDB("Currency")
				Return
		}
		If (This.Prop.RarityDivination)
		{
			If This.MatchNinjaDB("DivinationCard")
				Return
		}
		If (This.Prop.Prophecy)
		{
			If This.MatchNinjaDB("Prophecy")
				Return
		}
		If (This.Prop.TimelessSplinter || This.Prop.TimelessEmblem || This.Prop.BreachSplinter || This.Prop.Offering || This.Prop.Vessel || This.Prop.Scarab || This.Prop.SacrificeFragment || This.Prop.MortalFragment || This.Prop.GuardianFragment || This.Prop.ProphecyFragment|| This.Prop.ItemName ~= "Simulacrum")
		{
			If This.MatchNinjaDB("Fragment")
				Return
			If This.MatchNinjaDB("Scarab")
				Return
		}
		If (This.Prop.IsBeast)
		{
			If This.MatchNinjaDB("Beast", "ItemBase")
				Return
		}
		If (This.Prop.ItemClass ~= "Helmets" && This.Data.Blocks.HasKey("Enchant"))
		{
			For k, v in Ninja.HelmetEnchant
			{
				If (InStr(This.Data.Blocks.Enchant, v["name"]))
				{
					This.Prop.ChaosValue := This.GetValue("Prop","ChaosValue") + v["chaosValue"]
					This.Prop.ExaltValue := This.GetValue("Prop","ExaltValue") + v["exaltedValue"]
					This.Data.HelmNinja := v
					If (v["chaosValue"] >= 5)
						This.Prop.ValuableEnch := True
					Break
				}
			}
		}
		If (This.Prop.RarityUnique)
		{
			If (This.Prop.ItemClass ~= "(Belts|Amulets|Rings)")
			{
				If This.MatchNinjaDB("UniqueAccessory")
					Return
			}
			Else If (This.Prop.ItemClass ~= "(Body Armours|Gloves|Boots|Helmets|Shields|Quivers)")
			{
				If This.MatchNinjaDB("UniqueArmour")
					Return
			}
			Else If (This.Prop.ItemClass ~= "Flasks")
			{
				If This.MatchNinjaDB("UniqueFlask")
					Return
			}
			Else If (This.Prop.ItemClass ~= "Jewel")
			{
				If This.MatchNinjaDB("UniqueJewel")
					Return
			}
			Else If (This.Prop.IsWeapon)
			{
				If This.MatchNinjaDB("UniqueWeapon")
					Return
			}
			Else If (This.Prop.IsMap)
			{
				If This.MatchNinjaDB("UniqueMap","ItemBase","baseType")
					Return
			}
		}
		If (This.Prop.IsMap)
		{
			If This.MatchNinjaDB("Map","ItemBase","name")
				Return
		}
		If (This.Prop.ItemLevel >= 82 && This.Prop.Influence != "" && !This.Prop.RarityUnique)
		{
			For k, v in Ninja.BaseType
			{
				If (This.Prop.ItemBase = v["name"] 
				&& This.Prop.Influence ~= v["variant"] 
				&& This.Prop.ItemLevel >= v["levelRequired"])
				{
					This.Prop.ChaosValue := v["chaosValue"]
					This.Prop.ExaltValue := v["exaltedValue"]
					This.Data.BaseNinja := v
					If (v["chaosValue"] >= 5)
						This.Prop.ValuableBase := True
					; Return
					Break
				}
			}
		}
	}
	MatchNinjaDB(ApiStr,MatchKey:="ItemName",NinjaKey:="name"){
		For k, v in Ninja[ApiStr]
		{
			If (This.Prop[MatchKey] = v[NinjaKey])
			{
				If ((ApiStr = "Map" || ApiStr = "UniqueMap") 
				&& This.Prop.Map_Tier < v["mapTier"])
					Continue
				If (v["links"] && ApiStr ~= "Unique"
				&& This.Prop.Sockets_Link < v["links"])
					Continue
				This.Prop.ChaosValue := This.GetValue("Prop","ChaosValue") + v["chaosValue"]
				If v["exaltedValue"]
					This.Prop.ExaltValue := This.GetValue("Prop","ExaltValue") + v["exaltedValue"]
				This.Data.Ninja := v
				Return True
			}
		}
		Return False
	}
	DisplayPSA(){
		propText:=statText:=affixText:=modifierText:=""
		For key, value in This.Prop
		{
			If( RegExMatch(key, "^Required")
			|| RegExMatch(key, "^Rating")
			|| RegExMatch(key, "^Sockets")
			|| RegExMatch(key, "^Quality")
			|| RegExMatch(key, "^Map")
			|| RegExMatch(key, "^Heist_")
			|| RegExMatch(key, "^Stack")
			|| RegExMatch(key, "^Weapon"))
			{
				If indexOf(key,this.MatchedCLF)
					statText .= "CLF⭐"
				statText .= key . ":  " . value . "`n"
			}
			Else
			{
				If indexOf(key,this.MatchedCLF)
					propText .= "CLF⭐"
				propText .= key . ":  " . value . "`n"
			}
		}

		GuiControl, ItemInfo:, ItemInfoPropText, %propText%

		GuiControl, ItemInfo:, ItemInfoStatText, %statText%

		For key, value in This.Affix
		{
			If(!This.Modifier[key]){
					If (value != 0 && value != "" && value != False){
					If indexOf(key,this.MatchedCLF){
						affixText .= "CLF⭐"
					}
					affixText .= key . ":  " . value . "`n"
					}
			}Else{
				If indexOf(key,this.MatchedCLF){
					modifierText .= "CLF⭐"
				}
				modifierText .= key . ":  " . value . "`n"
			}
		}
		GuiControl, ItemInfo:, ItemInfoAffixText, %affixText%

		GuiControl, ItemInfo:, ItemInfoModifierText, %modifierText%

	}
	GraphNinjaPrices(){
		If This.Data.HasKey("Ninja") || This.Data.HasKey("HelmNinja") || This.Data.HasKey("BaseNinja")
		{
			Gosub, ShowGraph
			Gui, ItemInfo: Show, AutoSize, % This.Prop.ItemName " Sparkline"
		}
		Else
		{
			GoSub, noDataGraph
			GoSub, HideGraph
			Gui, ItemInfo: Show, AutoSize, % This.Prop.ItemName " has no Graph Data" (This.Prop.IsMap?" for this Tier":"")
			Return
		}
			
		If (This.Data.Ninja["paySparkLine"])
		{
			dataPayPoint := This.Data.Ninja["paySparkLine"]["data"]
			dataRecPoint := This.Data.Ninja["receiveSparkLine"]["data"]
			totalPayChange := This.Data.Ninja["paySparkLine"]["totalChange"]
			totalRecChange := This.Data.Ninja["receiveSparkLine"]["totalChange"]

			basePayPoint := 0
			For k, v in dataPayPoint
			{
				If Abs(v) > basePayPoint
					basePayPoint := Abs(v)
			}
			If basePayPoint = 0
			FormatStr := "{1:0.0f}"
			Else If basePayPoint < 1
			FormatStr := "{1:0.3f}"
			Else If basePayPoint < 10
			FormatStr := "{1:0.2f}"
			Else If basePayPoint < 100
			FormatStr := "{1:0.1f}"
			Else If basePayPoint > 100
			FormatStr := "{1:0.0f}"

			GuiControl,ItemInfo: , PercentText1G1, % Format(FormatStr,(basePayPoint*1.0)) "`%"
			GuiControl,ItemInfo: , PercentText1G2, % Format(FormatStr,(basePayPoint*0.9)) "`%"
			GuiControl,ItemInfo: , PercentText1G3, % Format(FormatStr,(basePayPoint*0.8)) "`%"
			GuiControl,ItemInfo: , PercentText1G4, % Format(FormatStr,(basePayPoint*0.7)) "`%"
			GuiControl,ItemInfo: , PercentText1G5, % Format(FormatStr,(basePayPoint*0.6)) "`%"
			GuiControl,ItemInfo: , PercentText1G6, % Format(FormatStr,(basePayPoint*0.5)) "`%"
			GuiControl,ItemInfo: , PercentText1G7, % Format(FormatStr,(basePayPoint*0.4)) "`%"
			GuiControl,ItemInfo: , PercentText1G8, % Format(FormatStr,(basePayPoint*0.3)) "`%"
			GuiControl,ItemInfo: , PercentText1G9, % Format(FormatStr,(basePayPoint*0.2)) "`%"
			GuiControl,ItemInfo: , PercentText1G10, % Format(FormatStr,(basePayPoint*0.1)) "`%"
			GuiControl,ItemInfo: , PercentText1G11, % "0`%"
			GuiControl,ItemInfo: , PercentText1G12, % Format(FormatStr,-(basePayPoint*0.1)) "`%"
			GuiControl,ItemInfo: , PercentText1G13, % Format(FormatStr,-(basePayPoint*0.2)) "`%"
			GuiControl,ItemInfo: , PercentText1G14, % Format(FormatStr,-(basePayPoint*0.3)) "`%"
			GuiControl,ItemInfo: , PercentText1G15, % Format(FormatStr,-(basePayPoint*0.4)) "`%"
			GuiControl,ItemInfo: , PercentText1G16, % Format(FormatStr,-(basePayPoint*0.5)) "`%"
			GuiControl,ItemInfo: , PercentText1G17, % Format(FormatStr,-(basePayPoint*0.6)) "`%"
			GuiControl,ItemInfo: , PercentText1G18, % Format(FormatStr,-(basePayPoint*0.7)) "`%"
			GuiControl,ItemInfo: , PercentText1G19, % Format(FormatStr,-(basePayPoint*0.8)) "`%"
			GuiControl,ItemInfo: , PercentText1G20, % Format(FormatStr,-(basePayPoint*0.9)) "`%"
			GuiControl,ItemInfo: , PercentText1G21, % Format(FormatStr,-(basePayPoint*1.0)) "`%"


			baseRecPoint := 0
			For k, v in dataRecPoint
			{
				If Abs(v) > baseRecPoint
					baseRecPoint := Abs(v)
			}
			If baseRecPoint = 0
			FormatStr := "{1:0.0f}"
			Else If baseRecPoint < 1
			FormatStr := "{1:0.3f}"
			Else If baseRecPoint < 10
			FormatStr := "{1:0.2f}"
			Else If baseRecPoint < 100
			FormatStr := "{1:0.1f}"
			Else If baseRecPoint > 100
			FormatStr := "{1:0.0f}"

			GuiControl,ItemInfo: , PercentText2G1, % Format(FormatStr,(baseRecPoint*1.0)) "`%"
			GuiControl,ItemInfo: , PercentText2G2, % Format(FormatStr,(baseRecPoint*0.9)) "`%"
			GuiControl,ItemInfo: , PercentText2G3, % Format(FormatStr,(baseRecPoint*0.8)) "`%"
			GuiControl,ItemInfo: , PercentText2G4, % Format(FormatStr,(baseRecPoint*0.7)) "`%"
			GuiControl,ItemInfo: , PercentText2G5, % Format(FormatStr,(baseRecPoint*0.6)) "`%"
			GuiControl,ItemInfo: , PercentText2G6, % Format(FormatStr,(baseRecPoint*0.5)) "`%"
			GuiControl,ItemInfo: , PercentText2G7, % Format(FormatStr,(baseRecPoint*0.4)) "`%"
			GuiControl,ItemInfo: , PercentText2G8, % Format(FormatStr,(baseRecPoint*0.3)) "`%"
			GuiControl,ItemInfo: , PercentText2G9, % Format(FormatStr,(baseRecPoint*0.2)) "`%"
			GuiControl,ItemInfo: , PercentText2G10, % Format(FormatStr,(baseRecPoint*0.1)) "`%"
			GuiControl,ItemInfo: , PercentText2G11, % "0`%"
			GuiControl,ItemInfo: , PercentText2G12, % Format(FormatStr,-(baseRecPoint*0.1)) "`%"
			GuiControl,ItemInfo: , PercentText2G13, % Format(FormatStr,-(baseRecPoint*0.2)) "`%"
			GuiControl,ItemInfo: , PercentText2G14, % Format(FormatStr,-(baseRecPoint*0.3)) "`%"
			GuiControl,ItemInfo: , PercentText2G15, % Format(FormatStr,-(baseRecPoint*0.4)) "`%"
			GuiControl,ItemInfo: , PercentText2G16, % Format(FormatStr,-(baseRecPoint*0.5)) "`%"
			GuiControl,ItemInfo: , PercentText2G17, % Format(FormatStr,-(baseRecPoint*0.6)) "`%"
			GuiControl,ItemInfo: , PercentText2G18, % Format(FormatStr,-(baseRecPoint*0.7)) "`%"
			GuiControl,ItemInfo: , PercentText2G19, % Format(FormatStr,-(baseRecPoint*0.8)) "`%"
			GuiControl,ItemInfo: , PercentText2G20, % Format(FormatStr,-(baseRecPoint*0.9)) "`%"
			GuiControl,ItemInfo: , PercentText2G21, % Format(FormatStr,-(baseRecPoint*1.0)) "`%"


			AvgPay := {}
			Loop 5
			{
				AvgPay[A_Index] := (dataPayPoint[A_Index+1] + dataPayPoint[A_Index+2]) / 2
			}
			paddedPayData := {}
			paddedPayData[1] := dataPayPoint[1]
			paddedPayData[2] := dataPayPoint[1]
			paddedPayData[3] := dataPayPoint[2]
			paddedPayData[4] := AvgPay[1]
			paddedPayData[5] := dataPayPoint[3]
			paddedPayData[6] := AvgPay[2]
			paddedPayData[7] := dataPayPoint[4]
			paddedPayData[8] := AvgPay[3]
			paddedPayData[9] := dataPayPoint[5]
			paddedPayData[10] := AvgPay[4]
			paddedPayData[11] := dataPayPoint[6]
			paddedPayData[12] := AvgPay[5]
			paddedPayData[13] := dataPayPoint[7]
			For k, v in paddedPayData
			{
				div := v / basePayPoint * 100
				XGraph_Plot( pGraph1, 100 - div, "", True )
				;MsgBox % "Key : " k "   Val : " v
			}
			AvgRec := {}
			Loop 5
			{
				AvgRec[A_Index] := (dataRecPoint[A_Index+1] + dataRecPoint[A_Index+2]) / 2
			}
			paddedRecData := {}
			paddedRecData[1] := dataRecPoint[1]
			paddedRecData[2] := dataRecPoint[1]
			paddedRecData[3] := dataRecPoint[2]
			paddedRecData[4] := AvgRec[1]
			paddedRecData[5] := dataRecPoint[3]
			paddedRecData[6] := AvgRec[2]
			paddedRecData[7] := dataRecPoint[4]
			paddedRecData[8] := AvgRec[3]
			paddedRecData[9] := dataRecPoint[5]
			paddedRecData[10] := AvgRec[4]
			paddedRecData[11] := dataRecPoint[6]
			paddedRecData[12] := AvgRec[5]
			paddedRecData[13] := dataRecPoint[7]
			For k, v in paddedRecData
			{
				div := v / baseRecPoint * 100
				XGraph_Plot( pGraph2, 100 - div, "", True )
				;MsgBox % "Key : " k "   Val : " v
			}

			GuiControl,ItemInfo: , GroupBox1, % "Sell " This.Prop.ItemName " to Chaos"
			GuiControl,ItemInfo: , PComment1, Sell Value
			GuiControl,ItemInfo: , PData1, % sellval := (1 / This.Data.Ninja["pay"]["value"])
			GuiControl,ItemInfo: , PComment2, Sell Value `% Change
			GuiControl,ItemInfo: , PData2, % This.Data.Ninja["paySparkLine"]["totalChange"]
			GuiControl,ItemInfo: , PComment3, Orb per Chaos
			GuiControl,ItemInfo: , PData3, % This.Data.Ninja["pay"]["value"]
			GuiControl,ItemInfo: , PComment4, Day 6 Change
			GuiControl,ItemInfo: , PData4, % dataPayPoint[2]
			GuiControl,ItemInfo: , PComment5, Day 5 Change
			GuiControl,ItemInfo: , PData5, % dataPayPoint[3]
			GuiControl,ItemInfo: , PComment6, Day 4 Change
			GuiControl,ItemInfo: , PData6, % dataPayPoint[4]
			GuiControl,ItemInfo: , PComment7, Day 3 Change
			GuiControl,ItemInfo: , PData7, % dataPayPoint[5]
			GuiControl,ItemInfo: , PComment8, Day 2 Change
			GuiControl,ItemInfo: , PData8, % dataPayPoint[6]
			GuiControl,ItemInfo: , PComment9, Day 1 Change
			GuiControl,ItemInfo: , PData9, % dataPayPoint[7]
			GuiControl,ItemInfo: , PComment10, % Decimal2Fraction(sellval,"ID3")
			GuiControl,ItemInfo: , PData10, C / O

			GuiControl,ItemInfo: , GroupBox2, % "Buy " This.Prop.ItemName " from Chaos"
			GuiControl,ItemInfo: , SComment1, Buy Value
			GuiControl,ItemInfo: , SData1, % sellval := (This.Data.Ninja["receive"]["value"])
			GuiControl,ItemInfo: , SComment2, Buy Value `% Change
			GuiControl,ItemInfo: , SData2, % This.Data.Ninja["receiveSparkLine"]["totalChange"]
			GuiControl,ItemInfo: , SComment3, Orb per Chaos
			GuiControl,ItemInfo: , SData3, % 1 / This.Data.Ninja["receive"]["value"]
			GuiControl,ItemInfo: , SComment4, Day 6 Change
			GuiControl,ItemInfo: , SData4, % dataRecPoint[2]
			GuiControl,ItemInfo: , SComment5, Day 5 Change
			GuiControl,ItemInfo: , SData5, % dataRecPoint[3]
			GuiControl,ItemInfo: , SComment6, Day 4 Change
			GuiControl,ItemInfo: , SData6, % dataRecPoint[4]
			GuiControl,ItemInfo: , SComment7, Day 3 Change
			GuiControl,ItemInfo: , SData7, % dataRecPoint[5]
			GuiControl,ItemInfo: , SComment8, Day 2 Change
			GuiControl,ItemInfo: , SData8, % dataRecPoint[6]
			GuiControl,ItemInfo: , SComment9, Day 1 Change
			GuiControl,ItemInfo: , SData9, % dataRecPoint[7]
			GuiControl,ItemInfo: , SComment10, % Decimal2Fraction(sellval,"ID3")
			GuiControl,ItemInfo: , SData10, C / O

		}
		Else If (This.Data.Ninja["sparkline"] || This.Data.HelmNinja["sparkline"] || This.Data.BaseNinja["sparkline"] )
		{
			LTGraph := HTGraph := True
			If (This.Data.HasKey("Ninja"))
			{
				HTGraph := "Name"
				dataPoint := This.Data.Ninja["sparkline"]["data"]
				totalChange := This.Data.Ninja["sparkline"]["totalChange"]
			}
			Else
				HTGraph := False

			If (This.Data.HasKey("HelmNinja") && This.Data.HasKey("BaseNinja"))
			{
				dataPoint := This.Data.BaseNinja["sparkline"]["data"]
				totalChange := This.Data.BaseNinja["sparkline"]["totalChange"]
				dataLTPoint := This.Data.HelmNinja["sparkline"]["data"]
				totalLTChange := This.Data.HelmNinja["sparkline"]["totalChange"]
				HTGraph := "Base"
				LTGraph := "Helm"
			}
			Else If (This.Data.HasKey("BaseNinja"))
			{
				dataLTPoint := This.Data.BaseNinja["sparkline"]["data"]
				totalLTChange := This.Data.BaseNinja["sparkline"]["totalChange"]
				LTGraph := "Base"
			}
			Else If (This.Data.HasKey("HelmNinja"))
			{
				dataLTPoint := This.Data.HelmNinja["sparkline"]["data"]
				totalLTChange := This.Data.HelmNinja["sparkline"]["totalChange"]
				LTGraph := "Helm"
			}
			Else
			{
				LTGraph := False
				GoSub, noDataGraph2
				GoSub, noDataGraph2
			}

			If (HTGraph)
			{
				basePoint := 0
				For k, v in dataPoint
				{
					If (Abs(v) > basePoint)
						basePoint := Abs(v)
				}
				If basePoint = 0
				FormatStr := "{1:0.0f}"
				Else If basePoint < 1
				FormatStr := "{1:0.3f}"
				Else If basePoint < 10
				FormatStr := "{1:0.2f}"
				Else If basePoint < 100
				FormatStr := "{1:0.1f}"
				Else If basePoint > 100
				FormatStr := "{1:0.0f}"

				GuiControl,ItemInfo: , PercentText1G1, % Format(FormatStr,(basePoint*1.0)) "`%"
				GuiControl,ItemInfo: , PercentText1G2, % Format(FormatStr,(basePoint*0.9)) "`%"
				GuiControl,ItemInfo: , PercentText1G3, % Format(FormatStr,(basePoint*0.8)) "`%"
				GuiControl,ItemInfo: , PercentText1G4, % Format(FormatStr,(basePoint*0.7)) "`%"
				GuiControl,ItemInfo: , PercentText1G5, % Format(FormatStr,(basePoint*0.6)) "`%"
				GuiControl,ItemInfo: , PercentText1G6, % Format(FormatStr,(basePoint*0.5)) "`%"
				GuiControl,ItemInfo: , PercentText1G7, % Format(FormatStr,(basePoint*0.4)) "`%"
				GuiControl,ItemInfo: , PercentText1G8, % Format(FormatStr,(basePoint*0.3)) "`%"
				GuiControl,ItemInfo: , PercentText1G9, % Format(FormatStr,(basePoint*0.2)) "`%"
				GuiControl,ItemInfo: , PercentText1G10, % Format(FormatStr,(basePoint*0.1)) "`%"
				GuiControl,ItemInfo: , PercentText1G11, % "0`%"
				GuiControl,ItemInfo: , PercentText1G12, % Format(FormatStr,-(basePoint*0.1)) "`%"
				GuiControl,ItemInfo: , PercentText1G13, % Format(FormatStr,-(basePoint*0.2)) "`%"
				GuiControl,ItemInfo: , PercentText1G14, % Format(FormatStr,-(basePoint*0.3)) "`%"
				GuiControl,ItemInfo: , PercentText1G15, % Format(FormatStr,-(basePoint*0.4)) "`%"
				GuiControl,ItemInfo: , PercentText1G16, % Format(FormatStr,-(basePoint*0.5)) "`%"
				GuiControl,ItemInfo: , PercentText1G17, % Format(FormatStr,-(basePoint*0.6)) "`%"
				GuiControl,ItemInfo: , PercentText1G18, % Format(FormatStr,-(basePoint*0.7)) "`%"
				GuiControl,ItemInfo: , PercentText1G19, % Format(FormatStr,-(basePoint*0.8)) "`%"
				GuiControl,ItemInfo: , PercentText1G20, % Format(FormatStr,-(basePoint*0.9)) "`%"
				GuiControl,ItemInfo: , PercentText1G21, % Format(FormatStr,-(basePoint*1.0)) "`%"

				Avg := {}
				Loop 5
				{
					Avg[A_Index] := ((dataPoint[A_Index+1]?dataPoint[A_Index+1]:0) + (dataPoint[A_Index+2]?dataPoint[A_Index+2]:0)) / 2
				}
				paddedData := {}
				paddedData[1] := (dataPoint[1]?dataPoint[1]:0)
				paddedData[2] := (dataPoint[1]?dataPoint[1]:0)
				paddedData[3] := (dataPoint[2]?dataPoint[2]:0)
				paddedData[4] := (Avg[1]?Avg[1]:0)
				paddedData[5] := (dataPoint[3]?dataPoint[3]:0)
				paddedData[6] := (Avg[2]?Avg[2]:0)
				paddedData[7] := (dataPoint[4]?dataPoint[4]:0)
				paddedData[8] := (Avg[3]?Avg[3]:0)
				paddedData[9] := (dataPoint[5]?dataPoint[5]:0)
				paddedData[10] := (Avg[4]?Avg[4]:0)
				paddedData[11] := (dataPoint[6]?dataPoint[6]:0)
				paddedData[12] := (Avg[5]?Avg[5]:0)
				paddedData[13] := (dataPoint[7]?dataPoint[7]:0)
				For k, v in paddedData
				{
					div := v / basePoint * 100
					XGraph_Plot( pGraph1, 100 - div, "", True )
					;MsgBox % "Key : " k "   Val : " v
				}

				GuiControl,ItemInfo: , GroupBox1, % (HTGraph = "Name"?"Value of " This.Prop.ItemName : (HTGraph = "Base" ? "Value of " This.Prop.ItemBase :"Value Title Undefined") )
				GuiControl,ItemInfo: , PComment1, Chaos Value
				GuiControl,ItemInfo: , PData1, % (HTGraph = "Name"?This.Data.Ninja["chaosValue"]:(HTGraph = "Base"?This.Data.BaseNinja["chaosValue"]:""))
				GuiControl,ItemInfo: , PComment2, Exalted Value
				GuiControl,ItemInfo: , PData2, % (HTGraph = "Name"?This.Data.Ninja["exaltedValue"]:(HTGraph = "Base"?This.Data.BaseNinja["exaltedValue"]:""))
				GuiControl,ItemInfo: , PComment3, Chaos Value `% Change
				GuiControl,ItemInfo: , PData3, % (HTGraph = "Name"?This.Data.Ninja["sparkline"]["totalChange"]:(HTGraph = "Base"?This.Data.BaseNinja["sparkline"]["totalChange"]:""))
				GuiControl,ItemInfo: , PComment4, Day 6 Change
				GuiControl,ItemInfo: , PData4, % dataPoint[2]
				GuiControl,ItemInfo: , PComment5, Day 5 Change
				GuiControl,ItemInfo: , PData5, % dataPoint[3]
				GuiControl,ItemInfo: , PComment6, Day 4 Change
				GuiControl,ItemInfo: , PData6, % dataPoint[4]
				GuiControl,ItemInfo: , PComment7, Day 3 Change
				GuiControl,ItemInfo: , PData7, % dataPoint[5]
				GuiControl,ItemInfo: , PComment8, Day 2 Change
				GuiControl,ItemInfo: , PData8, % dataPoint[6]
				GuiControl,ItemInfo: , PComment9, Day 1 Change
				GuiControl,ItemInfo: , PData9, % dataPoint[7]
				GuiControl,ItemInfo: , PComment10, 
				GuiControl,ItemInfo: , PData10,
			}
			Else
			{
				Gosub, noDataGraph1
				Gosub, HideGraph1
			}

			If (LTGraph)
			{
				baseLTPoint := 0
				For k, v in dataLTPoint
				{
					If Abs(v) > baseLTPoint
						baseLTPoint := Abs(v)
				}
				If baseLTPoint = 0
				FormatStr := "{1:0.0f}"
				If baseLTPoint < 1
				FormatStr := "{1:0.3f}"
				Else If baseLTPoint < 10
				FormatStr := "{1:0.2f}"
				Else If baseLTPoint < 100
				FormatStr := "{1:0.1f}"
				Else If baseLTPoint > 100
				FormatStr := "{1:0.0f}"

				GuiControl,ItemInfo: , PercentText2G1, % Format(FormatStr,(baseLTPoint*1.0)) "`%"
				GuiControl,ItemInfo: , PercentText2G2, % Format(FormatStr,(baseLTPoint*0.9)) "`%"
				GuiControl,ItemInfo: , PercentText2G3, % Format(FormatStr,(baseLTPoint*0.8)) "`%"
				GuiControl,ItemInfo: , PercentText2G4, % Format(FormatStr,(baseLTPoint*0.7)) "`%"
				GuiControl,ItemInfo: , PercentText2G5, % Format(FormatStr,(baseLTPoint*0.6)) "`%"
				GuiControl,ItemInfo: , PercentText2G6, % Format(FormatStr,(baseLTPoint*0.5)) "`%"
				GuiControl,ItemInfo: , PercentText2G7, % Format(FormatStr,(baseLTPoint*0.4)) "`%"
				GuiControl,ItemInfo: , PercentText2G8, % Format(FormatStr,(baseLTPoint*0.3)) "`%"
				GuiControl,ItemInfo: , PercentText2G9, % Format(FormatStr,(baseLTPoint*0.2)) "`%"
				GuiControl,ItemInfo: , PercentText2G10, % Format(FormatStr,(baseLTPoint*0.1)) "`%"
				GuiControl,ItemInfo: , PercentText2G11, % "0`%"
				GuiControl,ItemInfo: , PercentText2G12, % Format(FormatStr,-(baseLTPoint*0.1)) "`%"
				GuiControl,ItemInfo: , PercentText2G13, % Format(FormatStr,-(baseLTPoint*0.2)) "`%"
				GuiControl,ItemInfo: , PercentText2G14, % Format(FormatStr,-(baseLTPoint*0.3)) "`%"
				GuiControl,ItemInfo: , PercentText2G15, % Format(FormatStr,-(baseLTPoint*0.4)) "`%"
				GuiControl,ItemInfo: , PercentText2G16, % Format(FormatStr,-(baseLTPoint*0.5)) "`%"
				GuiControl,ItemInfo: , PercentText2G17, % Format(FormatStr,-(baseLTPoint*0.6)) "`%"
				GuiControl,ItemInfo: , PercentText2G18, % Format(FormatStr,-(baseLTPoint*0.7)) "`%"
				GuiControl,ItemInfo: , PercentText2G19, % Format(FormatStr,-(baseLTPoint*0.8)) "`%"
				GuiControl,ItemInfo: , PercentText2G20, % Format(FormatStr,-(baseLTPoint*0.9)) "`%"
				GuiControl,ItemInfo: , PercentText2G21, % Format(FormatStr,-(baseLTPoint*1.0)) "`%"

				LTAvg := {}
				Loop 5
				{
					LTAvg[A_Index] := (dataLTPoint[A_Index+1] + dataLTPoint[A_Index+2]) / 2
				}
				paddedLTData := {}
				paddedLTData[1] := (dataLTPoint[1]?dataLTPoint[1]:0)
				paddedLTData[2] := (dataLTPoint[1]?dataLTPoint[1]:0)
				paddedLTData[3] := (dataLTPoint[2]?dataLTPoint[2]:0)
				paddedLTData[4] := (LTAvg[1]?LTAvg[1]:0)
				paddedLTData[5] := (dataLTPoint[3]?dataLTPoint[3]:0)
				paddedLTData[6] := (LTAvg[2]?LTAvg[2]:0)
				paddedLTData[7] := (dataLTPoint[4]?dataLTPoint[4]:0)
				paddedLTData[8] := (LTAvg[3]?LTAvg[3]:0)
				paddedLTData[9] := (dataLTPoint[5]?dataLTPoint[5]:0)
				paddedLTData[10] := (LTAvg[4]?LTAvg[4]:0)
				paddedLTData[11] := (dataLTPoint[6]?dataLTPoint[6]:0)
				paddedLTData[12] := (LTAvg[5]?LTAvg[5]:0)
				paddedLTData[13] := (dataLTPoint[7]?dataLTPoint[7]:0)
				For k, v in paddedLTData
				{
					div := v / baseLTPoint * 100
					XGraph_Plot( pGraph2, 100 - div, "", True )
					;MsgBox % "Key : " k "   Val : " v
				}

				GuiControl,ItemInfo: , GroupBox2, % (LTGraph = "Base"? ("Value of " This.Prop.ItemLevel " " This.Prop.Influence " " This.Prop.ItemBase ) : (LTGraph = "Helm" ? "Value of " This.Data.HelmNinja["name"] : "") )
				GuiControl,ItemInfo: , SComment1, Chaos Value
				GuiControl,ItemInfo: , SData1, % (LTGraph = "Base"? This.Data.BaseNinja["chaosValue"] : (LTGraph = "Helm" ? This.Data.HelmNinja["chaosValue"] : "") )
				GuiControl,ItemInfo: , SComment2, 
				GuiControl,ItemInfo: , SData2, 
				GuiControl,ItemInfo: , SComment3, Chaos Value `% Change
				GuiControl,ItemInfo: , SData3, % (LTGraph = "Base"? This.Data.BaseNinja["sparkline"]["totalChange"] : (LTGraph = "Helm" ? This.Data.HelmNinja["sparkline"]["totalChange"] : "") )
				GuiControl,ItemInfo: , SComment4, Day 6 Change
				GuiControl,ItemInfo: , SData4, % dataLTPoint[2]
				GuiControl,ItemInfo: , SComment5, Day 5 Change
				GuiControl,ItemInfo: , SData5, % dataLTPoint[3]
				GuiControl,ItemInfo: , SComment6, Day 4 Change
				GuiControl,ItemInfo: , SData6, % dataLTPoint[4]
				GuiControl,ItemInfo: , SComment7, Day 3 Change
				GuiControl,ItemInfo: , SData7, % dataLTPoint[5]
				GuiControl,ItemInfo: , SComment8, Day 2 Change
				GuiControl,ItemInfo: , SData8, % dataLTPoint[6]
				GuiControl,ItemInfo: , SComment9, Day 1 Change
				GuiControl,ItemInfo: , SData9, % dataLTPoint[7]
				GuiControl,ItemInfo: , SComment10,
				GuiControl,ItemInfo: , SData10,
			}
			Else
			{
				Gosub, noDataGraph2
				Gosub, HideGraph2
			}

		}
		Return

		noDataGraph:
			GoSub, noDataGraph1
			GoSub, noDataGraph2
		Return

		noDataGraph1:
			Loop 21
			{
				GuiControl,ItemInfo: , PercentText1G%A_Index%, 0`%
			}
			GuiControl,ItemInfo: , GroupBox1, No Data
			Loop 13
			{
				XGraph_Plot( pGraph1, 100, "", True )
			}
			Loop 10
			{
				GuiControl,ItemInfo: , PComment%A_Index%,
				GuiControl,ItemInfo: , PData%A_Index%,
			}
		Return

		noDataGraph2:
			Loop 21
			{
				GuiControl,ItemInfo: , PercentText2G%A_Index%, 0`%
			}
			GuiControl,ItemInfo: , GroupBox2, No Data
			Loop 13
			{
				XGraph_Plot( pGraph2, 100, "", True )
			}
			Loop 10
			{
				GuiControl,ItemInfo: , SComment%A_Index%,
				GuiControl,ItemInfo: , SData%A_Index%,
			}
		Return

		HideGraph:
			GoSub, HideGraph1
			GoSub, HideGraph2
		Return

		HideGraph1:
			Loop 21
			{
				GuiControl,ItemInfo: Hide, PercentText1G%A_Index%
			}
			GuiControl,ItemInfo: Hide, pGraph1
			GuiControl,ItemInfo: Hide, GroupBox1
			Loop 10
			{
				GuiControl,ItemInfo: Hide, PComment%A_Index%
				GuiControl,ItemInfo: Hide, PData%A_Index%
			}
		Return

		HideGraph2:
			Loop 21
			{
				GuiControl,ItemInfo: Hide, PercentText2G%A_Index%
			}
			GuiControl,ItemInfo: Hide, pGraph2
			GuiControl,ItemInfo: Hide, GroupBox2
			Loop 10
			{
				GuiControl,ItemInfo: Hide, SComment%A_Index%
				GuiControl,ItemInfo: Hide, SData%A_Index%
			}
		Return

		ShowGraph:
			Loop 2
			{
				aVal := A_Index
				Loop 21
				{
					GuiControl,ItemInfo: Show, PercentText%aVal%G%A_Index%
				}
				GuiControl,ItemInfo: Show, pGraph%aVal%
				GuiControl,ItemInfo: Show, GroupBox%aVal%
			}
			Loop 10
			{
				GuiControl,ItemInfo: Show, PComment%A_Index%
				GuiControl,ItemInfo: Show, PData%A_Index%
				GuiControl,ItemInfo: Show, SComment%A_Index%
				GuiControl,ItemInfo: Show, SData%A_Index%
			}
			aVal := ""
		Return
	}
	ItemInfo(){
		This.MatchLootFilter()
		This.DisplayPSA()
		This.GraphNinjaPrices()
	}
	MatchStashManagement(passthrough:=False){
		; Create associative array so HasKey function can be used
		UnsupportedAffinityCurrencies := { "Stacked Deck":0
																			, "Prime Regrading Lens":0
																			, "Secondary Regrading Lens":0
																			, "Veiled Chaos Orb":0
																			, "Vial of Transcendence":0
																			, "Vial of Sacrifice":0
																			, "Vial of the Ghost":0
																			, "Vial of Consequence":0
																			, "Vial of Summoning":0
																			, "Vial of Dominance":0
																			, "Vial of Awakening":0
																			, "Vial of the Ritual":0
																			, "Vial of Fate":0
																			, "Bestiary Orb":0
																			, "Blessing of Chayula":0
																			, "Blessing of Xoph":0
																			, "Blessing of Uul-Netol":0
																			, "Blessing of Tul":0
																			, "Blessing of Esh":0 }
		If (StashTabYesCurrency && This.Prop.RarityCurrency && (This.Prop.SpecialType="" || This.Prop.SpecialType = "Ritual Item"))
		{
			If (StashTabYesCurrency > 1 && !UnsupportedAffinityCurrencies.HasKey(This.Prop.ItemName))
				sendstash := -2
			Else
				sendstash := StashTabCurrency
		}
		Else If (StashTabYesNinjaPrice && This.Prop.ChaosValue >= StashTabYesNinjaPrice_Price && !This.Prop.IsMap)
			sendstash := StashTabNinjaPrice
		Else If (This.Prop.Expedition)
			Return -2
		Else If (This.Prop.Heist)
			Return -2
		Else If (This.Prop.Incubator)
			Return -1
		;Affinities
		Else If (This.Prop.IsBlightedMap || This.Prop.Oil) && StashTabYesBlight
		{
			If StashTabYesBlight > 1
				sendstash := -2
			Else
				sendstash := StashTabBlight
		}
		Else If ((This.Prop.IsBrickedMap) && StashTabYesBrickedMaps)
				sendstash := StashTabBrickedMaps
		Else If (This.Prop.IsMap && StashTabYesMap)
		{
			If StashTabYesMap > 1
				sendstash := -2
			Else
				sendstash := StashTabMap
		}
		Else If (This.Prop.Catalyst || This.Prop.IsOrgan != "") && StashTabYesMetamorph
		{
			If StashTabYesMetamorph > 1
				sendstash := -2
			Else
				sendstash := StashTabMetamorph
		}
		Else If (This.Prop.SpecialType="Delirium" && StashTabYesDelirium)
		{
			If StashTabYesDelirium > 1
				sendstash := -2
			Else
				sendstash := StashTabDelirium
		}
		Else If (This.Prop.TimelessSplinter || This.Prop.TimelessEmblem || This.Prop.BreachSplinter || This.Prop.Offering || This.Prop.UberDuberOffering || This.Prop.Vessel || This.Prop.Scarab || This.Prop.SacrificeFragment || This.Prop.MortalFragment || This.Prop.GuardianFragment || This.Prop.ProphecyFragment )&&StashTabYesFragment
		{
			If StashTabYesFragment > 1 
				sendstash := -2
			Else
				sendstash := StashTabFragment 
		}
		Else If (This.Prop.RarityDivination) && StashTabYesDivination
		{
			If StashTabYesDivination > 1
				sendstash := -2
			Else
				sendstash := StashTabDivination
		}
		Else If (This.Prop.Essence) && StashTabYesEssence
		{
			If StashTabYesEssence > 1
				sendstash := -2
			Else
				sendstash := StashTabEssence
		}
		Else If (This.Prop.Fossil || This.Prop.Resonator) && StashTabYesDelve
		{
			If StashTabYesDelve > 1
				sendstash := -2
			Else
				sendstash := StashTabDelve
		}
		Else If ((StashTabYesUnique||StashTabYesUniqueRing||StashTabYesUniqueDump) && This.Prop.RarityUnique && This.Prop.IsOrgan="" 
		&&( !StashTabYesUniquePercentage || (StashTabYesUniquePercentage && This.Prop.PercentageAffix >= StashTabUniquePercentage) ) )
		{
			If (StashTabYesUnique = 2)
				Return -2
			Else if (StashTabYesUnique)
			sendstash := StashTabUnique
			Else If (StashTabYesUniqueRing&&This.Prop.Ring)
			sendstash := StashTabUniqueRing
			Else If (StashTabYesUniqueDump)
			sendstash := StashTabUniqueDump
		}
		Else If ( ((StashTabYesUniqueRing&&StashTabYesUniqueRingAll&&This.Prop.Ring) || (StashTabYesUniqueDump&&StashTabYesUniqueDumpAll)) && This.Prop.RarityUnique && This.Prop.IsOrgan="" 
		&& (StashTabYesUniquePercentage && This.Prop.PercentageAffix < StashTabUniquePercentage)  )
		{
			If (StashTabYesUniqueRing&&StashTabYesUniqueRingAll&&This.Prop.Ring)
			sendstash := StashTabUniqueRing
			Else If (StashTabYesUniqueDump&&StashTabYesUniqueDumpAll)
			sendstash := StashTabUniqueDump
		}
		Else If (This.Prop.MiscMapItem&&StashTabYesMiscMapItems)
		{
			sendstash := StashTabMiscMapItems
		}
		Else If (This.Prop.Flask&&(This.Prop.Quality>0)&&StashTabYesFlaskQuality&&!This.Prop.RarityUnique)
			sendstash := StashTabFlaskQuality
		Else If (This.Prop.Flask&&(This.Prop.Quality<1)&&StashTabYesFlaskAll&&!This.Prop.RarityUnique)
			sendstash := StashTabFlaskAll																															
		Else If (This.Prop.RarityGem)
		{
			If ((This.Prop.Quality>0)&&StashTabYesGemQuality)
				sendstash := StashTabGemQuality
			Else If (This.Prop.VaalGem && StashTabYesGemVaal)
				sendstash := StashTabGemVaal
			Else If (This.Prop.Support && StashTabYesGemSupport)
				sendstash := StashTabGemSupport
			Else If (StashTabYesGem)
				sendstash := StashTabGem
		}
		Else If ((This.Prop.IsInfluenceItem||This.Prop.IsSynthesisItem&&YesIncludeFandSItem)&&StashTabYesInfluencedItem)
			sendstash := StashTabInfluencedItem
		Else If ((This.Prop.Sockets_Link >= 5)&&StashTabYesLinked)
			sendstash := StashTabLinked
		Else If (This.Prop.Prophecy&&StashTabYesProphecy)
			sendstash := StashTabProphecy
		Else If (This.Prop.Veiled&&StashTabYesVeiled)
			sendstash := StashTabVeiled
		Else If (This.Prop.ClusterJewel&&StashTabYesClusterJewel)
			sendstash := StashTabClusterJewel
		Else If (This.Prop.HeistGear&&StashTabYesHeistGear)
			sendstash := StashTabHeistGear
		Else If (StashTabYesCrafting 
			&& ((YesStashATLAS && This.Prop.CraftingBase = "Atlas Base" && ((This.Prop.ItemLevel >= YesStashATLASCraftingIlvlMin && YesStashATLASCraftingIlvl) || !YesStashATLASCraftingIlvl)) 
				|| (YesStashSTR && This.Prop.CraftingBase = "STR Base" && ((This.Prop.ItemLevel >= YesStashSTRCraftingIlvlMin && YesStashSTRCraftingIlvl) || !YesStashSTRCraftingIlvl)) 
				|| (YesStashDEX && This.Prop.CraftingBase = "DEX Base" && ((This.Prop.ItemLevel >= YesStashDEXCraftingIlvlMin && YesStashDEXCraftingIlvl) || !YesStashDEXCraftingIlvl)) 
				|| (YesStashINT && This.Prop.CraftingBase = "INT Base" && ((This.Prop.ItemLevel >= YesStashINTCraftingIlvlMin && YesStashINTCraftingIlvl) || !YesStashINTCraftingIlvl)) 
				|| (YesStashHYBRID && This.Prop.CraftingBase = "Hybrid Base" && ((This.Prop.ItemLevel >= YesStashHYBRIDCraftingIlvlMin && YesStashHYBRIDCraftingIlvl) || !YesStashHYBRIDCraftingIlvl)) 
				|| (YesStashJ && This.Prop.CraftingBase = "Jewel Base" && ((This.Prop.ItemLevel >= YesStashJCraftingIlvlMin && YesStashJCraftingIlvl) || !YesStashJCraftingIlvl)) 
				|| (YesStashAJ && This.Prop.CraftingBase = "Abyss Jewel Base" && ((This.Prop.ItemLevel >= YesStashAJCraftingIlvlMin && YesStashAJCraftingIlvl) || !YesStashAJCraftingIlvl))
				|| (YesStashJewellery && This.Prop.CraftingBase = "Jewellery Base" && ((This.Prop.ItemLevel >= YesStashJewelleryCraftingIlvlMin && YesStashJewelleryCraftingIlvl) || !YesStashJewelleryCraftingIlvl)) )
			&& (!This.Prop.Corrupted))
			sendstash := StashTabCrafting
		Else If (StashTabYesPredictive && PPServerStatus && This.Prop.PredictPrice >= StashTabYesPredictive_Price ){
			sendstash := StashTabPredictive
		}
		Else If (ChaosRecipeEnableFunction && This.StashChaosRecipe(passthrough))
		{
			If (ChaosRecipeStashMethodDump)
				sendstash := StashTabDump
			Else If (ChaosRecipeStashMethodTab)
				sendstash := ChaosRecipeStashTab
			Else If (ChaosRecipeStashMethodSort)
			{
				If (This.Prop.SlotType = "Body")
					sendstash := ChaosRecipeStashTabArmour
				Else If (This.Prop.SlotType = "One Hand" || This.Prop.SlotType = "Two Hand" || This.Prop.SlotType = "Shield")
					sendstash := ChaosRecipeStashTabWeapon
				Else If This.Prop.SlotType
				{
					w := This.Prop.SlotType
					sendstash := ChaosRecipeStashTab%w%
				}
			}
		}
		Else If (((StashDumpInTrial || StashTabYesDump) && CurrentLocation ~= "Aspirant's Trial") 
			|| (StashTabYesDump && (!StashDumpSkipJC || (StashDumpSkipJC && !(This.Prop.Jeweler || This.Prop.Chromatic)))))
			sendstash := StashTabDump, This.Prop.DumpTabItem := True
		Else If (This.Prop.SpecialType && This.Prop.SpecialType != "Heist Goods")
			Return -1
		Else
			Return False
		Return sendstash
	}
	MatchLootFilter(GroupOut:=0){
		For GKey, Groups in LootFilter
		{
			If (Groups.GroupType) {
				If (val := This.MatchGroup(Groups)){
					this.Prop.CLF_Tab := Groups["StashTab"]
					this.Prop.CLF_Group := (Groups["GroupName"]?Groups["GroupName"]:GKey)
					This.MatchedCLF := val
					Return this.Prop.CLF_Tab
				}
			} Else {
				this.MatchedCLF := []
				matched := False
				nomatched := False
				ormatched := 0
				ormismatch := False
				orcount := Groups["Data"]["OrCount"]
				For SKey, Selected in Groups
				{
					If ( SKey = "Data" )
						Continue
					For AKey, AVal in Selected {
						orflag := AVal["OrFlag"]
						If (AVal.GroupType){
							If keylist := This.MatchGroup(AVal) {
								matched := True
								If orflag
									ormatched++
								For _, __ in keylist
									this.MatchedCLF.Push(__)
							} Else {
								if !orflag
									nomatched := True
								ormismatch := True
							}
						} Else {
							arrval := Item[SKey][AVal["#Key"]]
							eval := AVal["Eval"]
							min := AVal["Min"]
							orflag := AVal["OrFlag"]

							If This.Evaluate(eval,arrval,min){
								matched := True
								If orflag
									ormatched++
								This.MatchedCLF.Push(AVal["#Key"])
							} Else {
								if !orflag
									nomatched := True
								ormismatch := True
							}
						}
					}
				}
				If (ormismatch && ormatched < orcount)
					nomatched := True
				If (matched && !nomatched)
				{
					this.Prop.CLF_Tab := Groups["Data"]["StashTab"]
					this.Prop.CLF_Group := GKey
					Return this.Prop.CLF_Tab
				}
			}
		}
		This.MatchedCLF := False
		Return False
	}
	MatchGroup(grp){
		local
		CountSum := 0
		PotentialMatches := []
		For k, elem in grp["~ElementList"] {
			If elem.GroupType {
				matched := This.MatchGroup(elem)
			} Else {
				arrval := This[elem["Type"]][elem["#Key"]]
				matched := This.Evaluate(elem["Eval"],arrval,elem["Min"])
			}
			If matched {
				If (grp.GroupType ~= "[nN][oO][tT]")
					Return False
				If elem["#Key"]
					PotentialMatches.Push(elem["#Key"])
				Else If IsObject(matched) {
					for kk, vv in matched {
						PotentialMatches.Push(vv)
					}
				}
				If (grp.GroupType ~= "[cC]ount"){
					CountSum += (elem["Weight"] != "" ? elem["Weight"] : 1)
				} Else If (grp.GroupType ~= "[wW]eight"){
					CountSum += (elem["Weight"] != "" ? elem["Weight"] : 1) * (arrval != "" ? arrval : 1)
				}
			} Else {
				If (grp.GroupType ~= "[aA][nN][dD]")
					Return False
			}
		}
		If (grp.GroupType ~= "[aA][nN][dD]" || grp.GroupType ~= "[nN][oO][tT]"){
			Return PotentialMatches
		}
		Else If (grp.GroupType ~= "[cC]ount" || grp.GroupType ~= "[wW]eight") {
			If (CountSum >= grp.TypeValue) {
				Return PotentialMatches
			} Else {
				Return False
			}
		}
	}
	Evaluate(eval,val,min){
		local
		if (eval = ">") {
			Return (val > min)
		} Else if (eval = ">=") {
			Return (val >= min)
		} Else if (eval = "=") {
			Return (val = min)
		} Else if (eval = "<") {
			Return (val < min)
		} else if (eval = "<=") {
			Return (val <= min)
		} else if (eval = ">0<") {
			Return (val > 0 && val < min)
		} else if (eval = ">0<=") {
			Return (val > 0 && val <= min)
		} else if (eval = "!=") {
			Return (val != min)
		} else if (eval = "~=") {
			Return (val ~= min)
		} else if (eval = "~") {
			matchedOR := False
			for k, v in StrSplit(min, "|"," ") { ; Split OR first
				if InStr(v, "&") { 					       ; Check for any & sections
					mismatched := false
					for kk, vv in StrSplit(v, "&"," ") { ; Split the array again
						If !InStr(val, vv)              ; Check AND sections for mismatch
							mismatched := true
					}
					if !mismatched {    ; no mismatch means all sections found in the string
						matchedOR := true 
						Break
					}
				}	Else if InStr(val, v)	{          ; If there was no & symbol this is an OR section
					matchedOR := True
					break
				}
			}
			Return matchedOR ; If any of the sections produced a match it will flag true
		}
	}
	inRange(key,obj,base){
		If (obj.ranges.Count() = 1) {
			If !((base[key] >= obj.ranges.1.1 && base[key] <= obj.ranges.1.2)
			|| (base[key] <= obj.ranges.1.1 && base[key] >= obj.ranges.1.2))
				Return False
		} Else If (obj.ranges.Count() >= 2) {
			for k, v in obj.ranges
			{
				If !((base[key "_Value" k] >= v.1 && base[key "_Value" k] <= v.2)
				|| (base[key "_Value" k] <= v.1 && base[key "_Value" k] >= v.2))
					Return False
			}
		} Else If (obj.values.Count() = 1) {
			If !(base[key] == obj.values.1 )
				Return False
		} Else If (obj.values.Count() >= 2) {
			for k, v in obj.values
				If !(base[key "_Value" k] == v )
					Return False
		}
		Return True
	}
	MatchCraftingBases(){
		If (This.Prop.Rarity_Digit == 4)
			Return False
		If(HasVal(WR.CustomCraftingBases.CustomBases[1],This.Prop.ItemBase))
		{
			This.Prop.CraftingBase := "Atlas Base"
		}
		Else If(HasVal(WR.CustomCraftingBases.CustomBases[2],This.Prop.ItemBase))
		{
			This.Prop.CraftingBase := "STR Base"
		}
		Else If(HasVal(WR.CustomCraftingBases.CustomBases[3],This.Prop.ItemBase))
		{
			This.Prop.CraftingBase := "DEX Base"
		}
		Else If(HasVal(WR.CustomCraftingBases.CustomBases[4],This.Prop.ItemBase))
		{
			This.Prop.CraftingBase := "INT Base"
		}
		Else If(HasVal(WR.CustomCraftingBases.CustomBases[5],This.Prop.ItemBase))
		{
			This.Prop.CraftingBase := "Hybrid Base"
		}
		Else If(HasVal(WR.CustomCraftingBases.CustomBases[6],This.Prop.ItemBase))
		{
			This.Prop.CraftingBase := "Jewel Base"
		}
		Else If(HasVal(WR.CustomCraftingBases.CustomBases[7],This.Prop.ItemBase))
		{
			This.Prop.CraftingBase := "Abyss Jewel Base"
		}
		Else If(HasVal(WR.CustomCraftingBases.CustomBases[8],This.Prop.ItemBase))
		{
			This.Prop.CraftingBase := "Jewellery Base"
		}
	}
	ApproximatePerfection(){
		For ku, unique in WR.data.Perfect
		{
			If ( This.Prop.ItemName = unique.name ) {
				If unique.pricePerfect
				{
					perccalc := This.percval(This.Prop.PercentageAffix,[unique.mean,unique.pricePerfect]) * (This.Prop.PercentageAffix/90)
					This.Prop.UniquePerfectValue := perccalc < unique.mean ? unique.mean 
					: perccalc > unique.pricePerfect ? unique.pricePerfect 
					: perccalc
					This.Prop.UniqueNormalMean := unique.mean?unique.mean:0
					This.Prop.UniquePerfectMaxVal := unique.pricePerfect
				} Else {
					This.Prop.UniquePerfectValue := 0
					This.Prop.UniqueNormalMean := unique.mean?unique.mean:0
					This.Prop.UniquePerfectMaxVal := 0
				}
				Return
			}
		}
		This.Prop.UniquePerfectValue := 0
		This.Prop.UniqueNormalMean := 0
		This.Prop.UniquePerfectMaxVal := 0
	}
	perc(value,range){
		Return abs(((value - range.1) * 100) / (range.2 - range.1))
	}
	percval(perc,range){
		Return ((perc * (range.2 - range.1) / 100) + range.1)
	}
}
