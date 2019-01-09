<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="/">
		<html>
			<body>
				<h2>SoldierSkill</h2>
				<table border="1">
					<tr bgcolor="#9acd32">
						<td>ID</td>
						<td>兵种技能名称</td>
						<td>兵种类型</td>
						<td>目标兵种</td>
						<td>伤害增幅</td>
						<td>伤害减免</td>
						<td>技能说明</td>
					</tr>
					<xsl:for-each select="SoldierSkills/Skill">
					<tr>
						<td><xsl:value-of select="@id"/></td>
						<td><xsl:value-of select="Name"/></td>
						<td><xsl:value-of select="SoldierType"/></td>
						<td><xsl:value-of select="TargetType"/></td>
						<td><xsl:value-of select="HurtIncrease"/>%</td>
						<td><xsl:value-of select="HurtReduce"/>%</td>
						<td><xsl:value-of select="Desc"/></td>
					</tr>
					</xsl:for-each>
				</table>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
