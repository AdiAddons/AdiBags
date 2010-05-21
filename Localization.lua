--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local L = setmetatable({}, {
	__index = function(self, key)
		if key ~= nil then
			--@debug@
			addon:Debug('Missing locale', tostring(key))
			--@end-debug@
			rawset(self, key, tostring(key))
		end
		return tostring(key)
	end,
})
addon.L = L

L["QUIVER_TAG"] = "Qu"
L["AMMO_TAG"] = "Am"
L["SOUL_BAG_TAG"] = "So"
L["LEATHERWORKING_BAG_TAG"] = "Le"
L["INSCRIPTION_BAG_TAG"] = "In"
L["HERB_BAG_TAG"] = "He"
L["ENCHANTING_BAG_TAG"] = "En"
L["ENGINEERING_BAG_TAG"] = "Eg"
L["KEYRING_TAG"] = "Ke"
L["GEM_BAG_TAG"] = "Ge"
L["MINING_BAG_TAG"] = "Mi"

-- AH (sub)categories
L['Recipe'] = true
L["Consumable"] = true
L["Miscellaneous"] = true
L["Trade Goods"] = true
L["Gem"] = true
L['Glyph'] = true
L["Quest"] = true
L["Junk"] = true
-- End of AH (sub)categories

L["AdiBags anchor"] = true
L["Adjust the maximum number of items per row for each column."] = true
L["Adjust the maximum number of items per row."] = true
L["Adjust the maximum number of rows."] = true
L["Allow you manually redefine the section in which an item should be put. Simply drag an item on the section title."] = true
L["Ammunition"] = true
L["Ammunition and soul shards"] = true
L["Are you sure you want to remove this association ?"] = true
L["Backpack"] = true
L["Backpack background color"] = true
L["Bag height"] = true
L["Bag type"] = true
L["Bag usage format"] = true
L["Bag width"] = true
L["Bags"] = true
L["Bank"] = true
L["Bank background color"] = true
L["Basic AdiBags configuration"] = true
L["By category, subcategory, quality and item level (default)"] = true
L["By name"] = true
L["By quality and item level"] = true
L["Check sets that should be merged into a unique \"Sets\" section. This is obviously a per-character setting."] = true
L["Check this to display a bag type tag in the top left corner of items."] = true
L["Check this to display a colored border around items, based on item quality."] = true
L["Check this to display an icon after usage of each type of bags."] = true
L["Check this to display an indicator on quest items."] = true
L["Check this to display an textual tag before usage of each type of bags."] = true
L["Check this to display one individual section per set. If this is disabled, there will be one big \"Sets\" section."] = true
L["Check this to display one section per inventory slot."] = true
L["Check this to display only one value counting all equipped bags, ignoring their type."] = true
L["Check this to have the bag content spread over several columns."] = true
L["Check this to show space at your bank in the plugin."] = true
L["Check to enable this module."] = true
L["Click there to reset the bag positions and sizes."] = true
L["Click to reset item status."] = true
L["Click to tidy bags."] = true
L["Click to toggle the bag anchor."] = true
L["Click to toggle the equipped bag panel, so you can change them."] = true
L["Close"] = true
L["Column width"] = true
L["Configure"] = true
L["Consider gems as a subcategory of trade goods"] = true
L["Consider glyphs as a subcategory of trade goods"] = true
L["Consumable"] = true
L["Core"] = true
L["Display character money at bottom right of the backpack."] = true
L["Drop your item there to add it to this section."] = true
L["Enabled"] = true
L["Enter a text to search in item names."] = true
L["Equipment"] = true
L["Equipped bags"] = true
L["Filters"] = true
L["Filters are used to dispatch items in bag sections. One item can only appear in one section. If the same item is selected by several filters, the one with the highest priority wins."] = true
L["Free space"] = true
L["Free space / total space"] = true
L["Gear manager item sets"] = true
L["Gem"] = true
L["Gems are trade goods"] = true
L["Glyph"] = true
L["Glyphs are trade goods"] = true
L["Highlight color"] = true
L["Highlight scale"] = true
L["Incomplete stacks"] = true
L["Item category"] = true
L["Item search"] = true
L["Item-section associations"] = true
L["Items"] = true
L["Junk"] = true
L["LDB Plugin"] = true
L["Lock anchor"] = true
L["Manual filtering"] = true
L["Merge bag types"] = true
L["Merged sets"] = true
L["Miscellaneous"] = true
L["Money"] = true
L["Multi-column layout"] = true
L["New"] = true
L["New item highlight"] = true
L["One section per set"] = true
L["Other items"] = true
L["Please note this filter matchs every item. Any filter with lower priority than this one will have no effect."] = true
L["Plugins"] = true
L["Priority"] = true
L["Provides a LDB data source to be displayed by LDB display addons."] = true
L["Provides a text widget at top of the backpack where you can type (part of) an item name to locate it in your bags."] = true
L["Put ammunition and soul shards in their own sections."] = true
L["Put any item that can be equipped (including bags) into the \"Equipment\" section."] = true
L["Put items belonging to one or more sets of the built-in gear manager in specific sections."] = true
L["Put items in sections depending on their first-level category at the Auction House."] = true
L["Put items of poor quality or labeled as junk in the \"Junk\" section."] = true
L["Put quest-related items in their own section."] = true
L["Quality highlight"] = true
L["Quality opacity"] = true
L["Quest"] = true
L["Quest indicator"] = true
L["Quest Items"] = true
L["Recipe"] = true
L["Reset new items"] = true
L["Reset position"] = true
L["Scale"] = true
L["Search:"] = true
L["Select how bag usage should be formatted in the plugin."] = true
L["Select how items should be sorted within each section."] = true
L["Select which first-level categories should be split by sub-categories."] = true
L["Set: %s"] = true
L["Sets"] = true
L["Show bag type icons"] = true
L["Show bag type tags"] = true
L["Show bank usage"] = true
L["Sorting order"] = true
L["Soul shards"] = true
L["Space in use"] = true
L["Space in use / total space"] = true
L["Split by inventory slot"] = true
L["Split by subcategories"] = true
L["Stackable items"] = true
L["Tidy bags"] = true
L["Tidy your bags by clicking on the small \"T\" button at the top left of bags. Special bags with free slots will be filled with macthing items and stackable items will be stacked to save space."] = true
L["Toggle and configure item filters."] = true
L["Toggle and configure plugins."] = true
L["Track new items"] = true
L["Track new items in each bag, displaying a glowing aura over them and putting them in a special section. \"New\" status can be reset by clicking on the small \"N\" button at top left of bags."] = true
L["Trade Goods"] = true
L["Uncheck this to remove this association."] = true
L["Unlock anchor"] = true
L["Use this to adjust the bag scale."] = true
L["Use this to adjust the quality-based border opacity. 100% means fully opaque."] = true
L["Virtual stacks"] = true
L["Virtual stacks display in one place items that actually spread over several bag slots."] = true

-- Replace true with the key
for k, v in pairs(L) do if v == true then L[k] = k end end

--------------------------------------------------------------------------------
-- Locales from localization system (not yet)
--------------------------------------------------------------------------------

-- %Localization: adibags
-- AUTOMATICALLY GENERATED BY UpdateLocalization.lua
-- ANY CHANGE BELOW THIS LINE WILL BE LOST ON NEXT UPDATE
-- CHANGES SHOULD BE MADE USING http://www.wowace.com/addons/adibags/localization/

local locale = GetLocale()
if locale == "frFR" then
L["AdiBags anchor"] = "Ancre AdiBags"
L["Adjust the maximum number of items per row."] = "Ajustez le nombre maximale d'objets par ligne."
L["Adjust the maximum number of items per row for each column."] = "Ajustez le nombre maximal d'objet par ligne de chaque colonne."
L["Adjust the maximum number of rows."] = "Ajustez le nombre maximal de lignes."
L["Allow you manually redefine the section in which an item should be put. Simply drag an item on the section title."] = "Vous permet de redéfinir manuellement la section dans laquelle un objet doit être mis. Tirez simplement un objet sur le titre de section."
L["AMMO_TAG"] = "Ba"
L["Ammunition"] = "Munitions"
L["Ammunition and soul shards"] = "Munitions et fragments d'âme."
L["Are you sure you want to remove this association ?"] = "Etes-vous sûr de vouloir supprimer cette association ?"
L["Backpack"] = "Sac à dos"
L["Backpack background color"] = "Couleur du fond du sac à dos"
L["Bag height"] = "Hauteur des sacs"
L["Bags"] = "Sacs"
L["Bag type"] = "Type de sac"
L["Bag usage format"] = "Format de l'usage des sacs"
L["Bag width"] = "Largeur des sacs"
L["Bank"] = "Banque"
L["Bank background color"] = "Couleur du fond de la banque"
L["Basic AdiBags configuration"] = "Configuration basique d'AdiBags"
L["By category, subcategory, quality and item level (default)"] = "Par catégorie, sous-catégorie, qualité et niveau d'objet (par défaut)"
L["By name"] = "Par nom"
L["By quality and item level"] = "Par qualité et niveau d'objet"
L["Check sets that should be merged into a unique \"Sets\" section. This is obviously a per-character setting."] = "Cochez les ensembles qui doivent être fusionnés en une section \"Ensembles\" unique. C'est évident un réglage spécifique à ce personnage."
L["Check this to display a bag type tag in the top left corner of items."] = "Cochez ceci pour afficher le type des sacs dans le coin supérieur gauche des objets."
L["Check this to display a colored border around items, based on item quality."] = "Cochez ceci pour afficher un bord coloré autour des objets basé sur leur qualité."
L["Check this to display an icon after usage of each type of bags."] = "Cochez ceci pour afficher une icône de type de sac après l'usage."
L["Check this to display an indicator on quest items."] = "Cochez ceci pour afficher un indicateur sur les objets de quête."
L["Check this to display an textual tag before usage of each type of bags."] = "Cochez ceci pour afficher le type de sac avant l'usage."
L["Check this to display one individual section per set. If this is disabled, there will be one big \"Sets\" section."] = "Cochez ceci pour afficher une section individuel par ensemble d'équipement. Sinon, il n'y aura qu'une seule section \"Ensembles\"."
L["Check this to display one section per inventory slot."] = "Cochez ceci pour répartir les objets selon l'emplacement d'inventaire."
L["Check this to display only one value counting all equipped bags, ignoring their type."] = "Cochez ceci pour n'afficher qu'une seule valeur pour tous les sacs, quelque soit leur type."
L["Check this to have the bag content spread over several columns."] = "Cochez ceci pour que le contenu du sac soit affiché sur plusieurs colonnes."
L["Check this to show space at your bank in the plugin."] = "Cochez ceci pour afficher l'espace libre de votre banque."
L["Check to enable this module."] = "Cochez cette case pour activer ce module."
L["Click there to reset the bag positions and sizes."] = "Cliquez ici pour remettre à zéro la position et la taille de sacs."
L["Click to reset item status."] = "Cliquez pour remettre à zéro les nouveaux objets."
L["Click to tidy bags."] = "Cliquez pour ranger les sacs."
L["Click to toggle the bag anchor."] = "Cliquez pour afficher/cacher l'ancre des sacs."
L["Click to toggle the equipped bag panel, so you can change them."] = "Cliquez pour afficher/cacher le panneau des sacs équipés. Vous pourrez ainsi les manipuler."
L["Close"] = "Fermer"
L["Column width"] = "Largeur de colonne"
L["Configure"] = "Configurer"
L["Consider gems as a subcategory of trade goods"] = "Considère les gemmes comme une sous-catégorie d'artisanat."
L["Consider glyphs as a subcategory of trade goods"] = "Considère les glyphes comme une sous-catégorie d'artisanat."
L["Consumable"] = "Consommable"
L["Core"] = "Noyau"
L["Display character money at bottom right of the backpack."] = "Affiche l'or du personnage en bas à droite du sac à dos."
L["Drop your item there to add it to this section."] = "Déposez votre objet ici pour l'ajouter à cette section."
L["Enabled"] = "Activé"
L["ENCHANTING_BAG_TAG"] = "En"
L["ENGINEERING_BAG_TAG"] = "In"
L["Enter a text to search in item names."] = "Saisissez un texte pour faire une recherche sur lesnboms d'objets."
L["Equipment"] = "Equipement"
L["Equipped bags"] = "Sacs équipés"
L["Filters"] = "Filtres"
L["Filters are used to dispatch items in bag sections. One item can only appear in one section. If the same item is selected by several filters, the one with the highest priority wins."] = "Les filtres sont utilisés pour répartir les objets en section de sac. un objet ne peut apparaître que dans une seule section. Si un objet correspond à plusieurs filtres, celui avec la meilleur priorité l'emporte."
L["Free space"] = "Espace libre"
L["Free space / total space"] = "Espace libre / espace total"
L["Gear manager item sets"] = "Ensembles d'objets du gestionnaire d'équipement"
L["Gem"] = "Gemme"
L["GEM_BAG_TAG"] = "Jo"
L["Gems are trade goods"] = "Gemmes dans artisanat"
L["Glyph"] = "Glyphe"
L["Glyphs are trade goods"] = "Glyphes dans artisanat"
L["HERB_BAG_TAG"] = "He"
L["Highlight color"] = "Couleur du surlignage"
L["Highlight scale"] = "Echelle du surlignage"
L["Incomplete stacks"] = "Piles incomplètes"
L["INSCRIPTION_BAG_TAG"] = "Ca"
L["Item category"] = "Catégories d'objets"
L["Items"] = "Objets"
L["Item search"] = "Recherche d'objet"
L["Junk"] = "Camelote"
L["KEYRING_TAG"] = "Cl"
L["LDB Plugin"] = "Plugin LDB"
L["LEATHERWORKING_BAG_TAG"] = "Cu"
L["Lock anchor"] = "Verrouiller l'ancre"
L["Manual filtering"] = "Filtrage manuel"
L["Merge bag types"] = "Fusionner les types de sacs"
L["Merged sets"] = "Ensembles fusionnés"
L["MINING_BAG_TAG"] = "Mi"
L["Miscellaneous"] = "Divers"
L["Money"] = "Monnaie"
L["Multi-column layout"] = "Disposition multi-colonnes"
L["New"] = "Nouveau"
L["New item highlight"] = "Surlignage des nouveaux objets"
L["One section per set"] = "Une section par ensemble"
L["Other items"] = "Autres objets"
L["Please note this filter matchs every item. Any filter with lower priority than this one will have no effect."] = "Veuillez notez que ce filtre correspond à tous les objets. Tout filtre avec une priorité plus faible que celle de ce filtre n'aura aucun effet."
L["Plugins"] = "Plugins"
L["Priority"] = "Priorité"
L["Provides a LDB data source to be displayed by LDB display addons."] = "Fournit une source LDB qui peut être affichée dans un addon d'affichage de LDB."
L["Provides a text widget at top of the backpack where you can type (part of) an item name to locate it in your bags."] = "Ajoute une zone de texte en haut du sac à dos, dans laquelle vous pouvez taper le nom (même partiel) d'un objet pour le retrouver dans vos sacs."
L["Put ammunition and soul shards in their own sections."] = "Place les munitions et les fragments d'âmes dans des sections spécifiques."
L["Put any item that can be equipped (including bags) into the \"Equipment\" section."] = "Place les objets qui peuvent être équipés (y compris les sacs) dans la section \"Equipement\"."
L["Put items belonging to one or more sets of the built-in gear manager in specific sections."] = "Place les objets appartenant à un ou plusieurs ensembles d'objet du gestionnaire d'objets dans des sections spécifiques."
L["Put items in sections depending on their first-level category at the Auction House."] = "Répartit les objets en fonction de leur catégorie principale (premier niveau de l'Hôtel des Ventes). "
L["Put items of poor quality or labeled as junk in the \"Junk\" section."] = "Place les objets de mauvaise qualité ou considéré comme camelote dans la section \"Camelote\"."
L["Put quest-related items in their own section."] = "Place les objets en rapport avec les quêtes dans une section spécifique."
L["Quality highlight"] = "Surlignage de la qualité"
L["Quality opacity"] = "Opacité du bord"
L["Quest"] = "Quête"
L["Quest indicator"] = "Indicateur de quête"
L["Quest Items"] = "Objets de quête"
L["QUIVER_TAG"] = "Fl"
L["Recipe"] = "Recette"
L["Reset new items"] = "Remet à zéro les nouveaux objets."
L["Reset position"] = "R.à.z. position"
L["Scale"] = "Echelle"
L["Search:"] = "Recherche :"
L["Select how bag usage should be formatted in the plugin."] = "Choisissez comment l'occupation d'un sac doit être formaté."
L["Select how items should be sorted within each section."] = "Choisissez comme les objets doivent triés à l'intérieur de chaque section."
L["Select which first-level categories should be split by sub-categories."] = "Sélectionnez quelles catégories doivent être séparée en sous-catégories."
L["Sets"] = "Ensembles"
L["Set: %s"] = "Ens.: %s"
L["Show bag type icons"] = "Affiche les icônes de type de sacs"
L["Show bag type tags"] = "Affiche les tags de type de sac"
L["Show bank usage"] = "Afficher la banque"
L["Sorting order"] = "Ordre de tri"
L["SOUL_BAG_TAG"] = "Âm"
L["Soul shards"] = "Fragments d'âme"
L["Space in use"] = "Espace utilisé"
L["Space in use / total space"] = "Espace utilisé / espace total"
L["Split by inventory slot"] = "Séparer par emplacement"
L["Split by subcategories"] = "Répartir par sous-catégorie"
L["Stackable items"] = "Objets empilables"
L["Tidy bags"] = "Ranger les sacs"
L["Tidy your bags by clicking on the small \"T\" button at the top left of bags. Special bags with free slots will be filled with macthing items and stackable items will be stacked to save space."] = "Range vos sacs lorsque vous cliquez sur le bouton \"T\" en haut à droite des sacs. Dans la mesure du possible, les sacs spéciaux seront remplis avec les objets correspondant, et les objets seront empilés pour libérer de la place."
L["Toggle and configure item filters."] = "Activer et configurer les filtres."
L["Toggle and configure plugins."] = "Activer et configurer les plugins."
L["Track new items"] = "Détection des nouveaux objets"
L["Track new items in each bag, displaying a glowing aura over them and putting them in a special section. \"New\" status can be reset by clicking on the small \"N\" button at top left of bags."] = "Détecte les nouveaux objets dans chaque sac, affiche une lueur colorée auteur d'eux et les place dans une section spéciale. Les nouveaux objets peuvent être remis à zéro en cliquant sur le bouton \"N\" en haut à droite des sacs."
L["Trade Goods"] = "Artisanat"
L["Unlock anchor"] = "Déverrouiler l'ancre"
L["Use this to adjust the bag scale."] = "Ajustez la taille des sacs."
L["Use this to adjust the quality-based border opacity. 100% means fully opaque."] = "Ajustez l'opacité de la bordure de qualité. 100% signifie complétement opaque."
L["Virtual stacks"] = "Piles virtuelles"
L["Virtual stacks display in one place items that actually spread over several bag slots."] = "Les piles virtuelles affichent en un seul endroit plusieurs piles d'objets."
elseif locale == "koKR" then
L["AdiBags anchor"] = "AdiBags 앵커"
L["Allow you manually redefine the section in which an item should be put. Simply drag an item on the section title."] = "수동으로 아이템을 넣을 섹션을 재설정합니다. 아이템을 드래그하여 섹션 제목에 놓으세요."
L["Ammunition"] = "탄약"
L["Ammunition and soul shards"] = "탄약과 영혼의 조각"
L["Bags"] = "가방"
L["Bank"] = "은행"
L["Basic AdiBags configuration"] = "기본 AdiBags 설정"
L["Check this to display a colored border around items, based on item quality."] = "아이템 품질에 따라서 아이템 외곽에 색깔을 표시하려면 이것을 체크하세요."
L["Check this to display one individual section per set. If this is disabled, there will be one big \"Sets\" section."] = "세트당 개별의 섹션으로 보이기 위해서는 이것을 체크하세요. 만일 하지 않으면, 하나의 큰 \"세트\" 섹션이 생길 것입니다."
L["Check to enable this module."] = "이 모듈을 사용하려면 체크하세요."
L["Close"] = "닫기"
L["Configure"] = "설정"
L["Enter a text to search in item names."] = "찾을 아이템 이름을 입력하세요."
L["Equipment"] = "장비"
L["Filters"] = "필터"
L["Free space"] = "빈 공간"
L["Free space / total space"] = "빈 공간 / 전체 공간"
L["Gear manager item sets"] = "장비 관리창 아이템 세트"
L["Item category"] = "아이템 종류"
L["Items"] = "아이템"
L["Item search"] = "아이템 찾기"
L["LDB Plugin"] = "LDB 플러그인"
L["Manual filtering"] = "수동 필터링"
L["Money"] = "소지금"
L["One section per set"] = "세트당 한개의 섹션"
L["Plugins"] = "플러그인"
L["Priority"] = "우선순위"
L["Put any item that can be equipped (including bags) into the \"Equipment\" section."] = "가방을 포함한 착용했던 아이템을 \"장비\" 섹센에 놓습니다."
L["Put quest-related items in their own section."] = "퀘스트와 관련된 아이템은 그들 자신의 섹션에 놓습니다."
L["Quest"] = "퀘스트"
L["Quest Items"] = "퀘스트 아이템"
L["Search:"] = "찾기:"
L["Sets"] = "세트"
L["Set: %s"] = "세트 : %s"
L["Sorting order"] = "분류 순서"
L["Soul shards"] = "영혼의 조각"
L["Track new items"] = "새 아이템 추적"
L["Unlock anchor"] = "앵커의 잠금 해제"
L["Virtual stacks"] = "가상 스택"
end
