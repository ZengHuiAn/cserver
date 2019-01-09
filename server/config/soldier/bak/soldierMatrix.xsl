<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:template match="/">
		<html>
			<body>
				<table cellspacing="10">
				<tr>
				<td>
					<h2>SoldierAttackMatrix</h2>
					<table border="1">
						<tr bgcolor="#9acd32">
							<td>目标</td> <td>步</td> <td>弓</td> <td>枪</td> <td>骑</td> <td>器</td>
						</tr>
						<xsl:for-each select="SoldierMatrix/Soldier">
						<tr>
							<td><xsl:value-of select="@type"/></td>
							<td><xsl:value-of select="Matrix[@target=1]/Attack"/></td>
							<td><xsl:value-of select="Matrix[@target=2]/Attack"/></td>
							<td><xsl:value-of select="Matrix[@target=3]/Attack"/></td>
							<td><xsl:value-of select="Matrix[@target=4]/Attack"/></td>
							<td><xsl:value-of select="Matrix[@target=5]/Attack"/></td>
						</tr>
						</xsl:for-each>
					</table>
				</td>
				<td>
					<h2>SoldierHitMatrix</h2>
					<table border="1">
						<tr bgcolor="#9acd32">
							<td>目标</td> <td>步</td> <td>弓</td> <td>枪</td> <td>骑</td> <td>器</td>
						</tr>
						<xsl:for-each select="SoldierMatrix/Soldier">
						<tr>
							<td><xsl:value-of select="@type"/></td>
							<td><xsl:value-of select="Matrix[@target=1]/Hit"/></td>
							<td><xsl:value-of select="Matrix[@target=2]/Hit"/></td>
							<td><xsl:value-of select="Matrix[@target=3]/Hit"/></td>
							<td><xsl:value-of select="Matrix[@target=4]/Hit"/></td>
							<td><xsl:value-of select="Matrix[@target=5]/Hit"/></td>
						</tr>
						</xsl:for-each>
					</table>
				</td>
				</tr>
				<tr>
				<td>
					<h2>SoldierBlockMatrix</h2>
					<table border="1">
						<tr bgcolor="#9acd32">
							<td>目标</td> <td>步</td> <td>弓</td> <td>枪</td> <td>骑</td> <td>器</td>
						</tr>
						<xsl:for-each select="SoldierMatrix/Soldier">
						<tr>
							<td><xsl:value-of select="@type"/></td>
							<td><xsl:value-of select="Matrix[@target=1]/Block"/></td>
							<td><xsl:value-of select="Matrix[@target=2]/Block"/></td>
							<td><xsl:value-of select="Matrix[@target=3]/Block"/></td>
							<td><xsl:value-of select="Matrix[@target=4]/Block"/></td>
							<td><xsl:value-of select="Matrix[@target=5]/Block"/></td>
						</tr>
						</xsl:for-each>
					</table>
				</td>
				<td>
					<h2>SoldierCritMatrix</h2>
					<table border="1">
						<tr bgcolor="#9acd32">
							<td>目标</td> <td>步</td> <td>弓</td> <td>枪</td> <td>骑</td> <td>器</td>
						</tr>
						<xsl:for-each select="SoldierMatrix/Soldier">
						<tr>
							<td><xsl:value-of select="@type"/></td>
							<td><xsl:value-of select="Matrix[@target=1]/Crit"/></td>
							<td><xsl:value-of select="Matrix[@target=2]/Crit"/></td>
							<td><xsl:value-of select="Matrix[@target=3]/Crit"/></td>
							<td><xsl:value-of select="Matrix[@target=4]/Crit"/></td>
							<td><xsl:value-of select="Matrix[@target=5]/Crit"/></td>
						</tr>
						</xsl:for-each>
					</table>
				</td>
				</tr>
				</table>
			</body>
		</html>
	</xsl:template>
</xsl:stylesheet>
