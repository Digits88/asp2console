<%
'
'	VBS JSON 2.0.3
'	Copyright (c) 2009 Tu�rul Topuz
'	Under the MIT (MIT-LICENSE.txt) license.
'

'Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

'The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Const JSON_OBJECT	= 0
Const JSON_ARRAY	= 1

Class jsCore
	Public Collection
	Public Count
	Public QuotedVars
	Public Kind ' 0 = object, 1 = array

	Private Sub Class_Initialize
		Set Collection = CreateObject("Scripting.Dictionary")
		QuotedVars = True
		Count = 0
	End Sub

	Private Sub Class_Terminate
		Set Collection = Nothing
	End Sub

	' counter
	Private Property Get Counter 
		Counter = Count
		Count = Count + 1
	End Property

	' - data maluplation
	' -- pair
	Public Property Let Pair(p, v)
		If IsNull(p) Then p = Counter
		Collection(p) = v
	End Property

	Public Property Set Pair(p, v)
		If IsNull(p) Then p = Counter
		If TypeName(v) <> "jsCore" Then
			Err.Raise &hD, "class: class", "Incompatible types: '" & TypeName(v) & "'"
		End If
		Set Collection(p) = v
	End Property

	Public Default Property Get Pair(p)
		If IsNull(p) Then p = Count - 1
		If IsObject(Collection(p)) Then
			Set Pair = Collection(p)
		Else
			Pair = Collection(p)
		End If
	End Property
	' -- pair
	Public Sub Clean
		Collection.RemoveAll
	End Sub

	Public Sub Remove(vProp)
		Collection.Remove vProp
	End Sub
	' data maluplation

	' encoding
	Function jsEncode(str)
		Dim charmap(127), haystack()
		charmap(8)  = "\b"
		charmap(9)  = "\t"
		charmap(10) = "\n"
		charmap(12) = "\f"
		charmap(13) = "\r"
		charmap(34) = "\"""
		charmap(47) = "\/"
		charmap(92) = "\\"

		Dim strlen : strlen = Len(str) - 1
		ReDim haystack(strlen)

		Dim i, charcode
		For i = 0 To strlen
			haystack(i) = Mid(str, i + 1, 1)

			charcode = AscW(haystack(i)) And 65535
			If charcode < 127 Then
				If Not IsEmpty(charmap(charcode)) Then
					haystack(i) = charmap(charcode)
				ElseIf charcode < 32 Then
					haystack(i) = "\u" & Right("000" & Hex(charcode), 4)
				End If
			Else
				haystack(i) = "\u" & Right("000" & Hex(charcode), 4)
			End If
		Next

		jsEncode = Join(haystack, "")
	End Function

	' converting
	Public Function toJSON(vPair)
		Select Case VarType(vPair)
			Case 0	' Empty
				toJSON = "null"
			Case 1	' Null
				toJSON = "null"
			Case 7	' Date
				' toJSON = "new Date(" & (vPair - CDate(25569)) * 86400000 & ")"	' let in only utc time
				toJSON = """" & CStr(vPair) & """"
			Case 8	' String
				toJSON = """" & jsEncode(vPair) & """"
			Case 9	' Object
				Dim bFI,i 
				bFI = True
				If vPair.Kind Then toJSON = toJSON & "[" Else toJSON = toJSON & "{"
				For Each i In vPair.Collection
					If bFI Then bFI = False Else toJSON = toJSON & ","

					If vPair.Kind Then 
						toJSON = toJSON & toJSON(vPair(i))
					Else
						If QuotedVars Then
							toJSON = toJSON & """" & i & """:" & toJSON(vPair(i))
						Else
							toJSON = toJSON & i & ":" & toJSON(vPair(i))
						End If
					End If
				Next
				If vPair.Kind Then toJSON = toJSON & "]" Else toJSON = toJSON & "}"
			Case 11
				If vPair Then toJSON = "true" Else toJSON = "false"
			Case 12, 8192, 8204
				toJSON = RenderArray(vPair, 1, "")
			Case Else
				toJSON = Replace(vPair, ",", ".")
		End select
	End Function

	Function RenderArray(arr, depth, parent)
		Dim first : first = LBound(arr, depth)
		Dim last : last = UBound(arr, depth)

		Dim index, rendered
		Dim limiter : limiter = ","

		RenderArray = "["
		For index = first To last
			If index = last Then
				limiter = ""
			End If 

			On Error Resume Next
			rendered = RenderArray(arr, depth + 1, parent & index & "," )

			If Err = 9 Then
				On Error GoTo 0
				RenderArray = RenderArray & toJSON(Eval("arr(" & parent & index & ")")) & limiter
			Else
				RenderArray = RenderArray & rendered & "" & limiter
			End If
		Next
		RenderArray = RenderArray & "]"
	End Function

	Public Property Get jsString
		jsString = toJSON(Me)
	End Property

	Sub Flush
		If TypeName(Response) <> "Empty" Then 
			Response.Write(jsString)
		ElseIf WScript <> Empty Then 
			WScript.Echo(jsString)
		End If
	End Sub

	Public Function Clone
		Set Clone = ColClone(Me)
	End Function

	Private Function ColClone(core)
		Dim jsc, i
		Set jsc = new jsCore
		jsc.Kind = core.Kind
		For Each i In core.Collection
			If IsObject(core(i)) Then
				Set jsc(i) = ColClone(core(i))
			Else
				jsc(i) = core(i)
			End If
		Next
		Set ColClone = jsc
	End Function

	Public Function HasChild(node)

		Dim key
		On Error Resume Next

		Set obj = Collection(node)
		key = obj.Collection.keys
		firstNode = key(0)

		HasChild = TypeName(firstNode) <> "Empty"

	End Function

	' M�todo adicionado para verificar a exist�ncia de um determinado objeto na cole��o.
	Public Function IsObjectNode(node, obj)

		Dim key, firstNode, actualNode
		On Error Resume Next

		If (Not IsObject(obj)) Then
			key = Collection.Keys
			firstNode = key(0)

			If (firstNode = node) Then
				IsObjectNode = True	
				Exit Function
			Else
				Set obj = Collection(firstNode)
				IsObjectNode = IsObjectNode(node, obj)
				Exit Function
			End If

		Else
			key = obj.Collection.Keys
			actualNode = key(0)

			If (actualNode = node) Then
				IsObjectNode = True
				Exit Function	
			Else
				Set obj = Collection(actualNode)
				If (Err = 424) Then
					IsObjectNode = False
					Exit Function
				End If
				IsObjectNode = IsObjectNode(node, obj)
				Exit Function
			End If		

		End If

		IsObjectNode = False

	End Function

End Class

Function jsObject
	Set jsObject = new jsCore
	jsObject.Kind = JSON_OBJECT
End Function

Function jsArray
	Set jsArray = new jsCore
	jsArray.Kind = JSON_ARRAY
End Function

Function toJSON(val)
	toJSON = (new jsCore).toJSON(val)
End Function
%>